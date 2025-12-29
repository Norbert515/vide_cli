import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:vm_service/vm_service.dart' as vms;
import 'package:vm_service/vm_service_io.dart';
import 'vm_service_evaluator.dart';

/// Result of Flutter instance startup
enum StartupStatus { success, failed, timeout }

class StartupResult {
  final StartupStatus status;
  final String? message;

  StartupResult.success({this.message}) : status = StartupStatus.success;
  StartupResult.failed(this.message) : status = StartupStatus.failed;
  StartupResult.timeout() : status = StartupStatus.timeout, message = null;

  bool get isSuccess => status == StartupStatus.success;
}

/// Represents a running Flutter application instance
class FlutterInstance {
  final String id;
  final Process process;
  final String workingDirectory;
  final List<String> command;
  final DateTime startedAt;

  String? _vmServiceUri;
  String? _deviceId;
  bool _isRunning = true;
  vms.VmService? _vmService;
  VmServiceEvaluator? _evaluator;

  /// The device pixel ratio from the last screenshot
  /// Used for converting physical pixels to logical pixels for tap coordinates
  double? _lastDevicePixelRatio;

  final _outputController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _startupCompleter = Completer<StartupResult>();

  // Buffer output lines so late listeners can receive them
  final _outputBuffer = <String>[];
  final _errorBuffer = <String>[];

  /// Stream of stdout output from the Flutter process
  /// Late listeners will receive buffered output
  Stream<String> get output =>
      _getBufferedStream(_outputController.stream, _outputBuffer);

  /// Stream of stderr output from the Flutter process
  /// Late listeners will receive buffered output
  Stream<String> get errors =>
      _getBufferedStream(_errorController.stream, _errorBuffer);

  /// Get all buffered output lines (for returning in tool result)
  List<String> get bufferedOutput => List.unmodifiable(_outputBuffer);

  /// Get all buffered error lines (for returning in tool result)
  List<String> get bufferedErrors => List.unmodifiable(_errorBuffer);

  Stream<String> _getBufferedStream(
    Stream<String> stream,
    List<String> buffer,
  ) async* {
    // First, yield all buffered items
    for (final item in buffer) {
      yield item;
    }
    // Then yield new items as they arrive
    await for (final item in stream) {
      yield item;
    }
  }

  /// VM Service URI (parsed from flutter run output)
  String? get vmServiceUri => _vmServiceUri;

  /// Device ID the app is running on
  String? get deviceId => _deviceId;

  /// Whether the instance is still running
  bool get isRunning => _isRunning;

  /// The device pixel ratio from the last screenshot
  /// Returns null if no screenshot has been taken yet, defaults to 2.0 in that case
  double get devicePixelRatio => _lastDevicePixelRatio ?? 2.0;

  /// Get the VM Service evaluator for advanced operations
  ///
  /// Returns null if VM Service is not connected or evaluator creation failed.
  /// This can be used to run diagnostic tests or custom evaluations.
  VmServiceEvaluator? get evaluator => _evaluator;

  FlutterInstance({
    required this.id,
    required this.process,
    required this.workingDirectory,
    required this.command,
    required this.startedAt,
  }) {
    _setupOutputParsing();
    _setupProcessExitHandler();
  }

  /// Wait for Flutter to start or fail
  /// Returns a [StartupResult] indicating success or failure
  /// Times out after 60 seconds by default
  Future<StartupResult> waitForStartup({
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      return await _startupCompleter.future.timeout(
        timeout,
        onTimeout: () => StartupResult.timeout(),
      );
    } catch (e) {
      return StartupResult.failed('Unexpected error: $e');
    }
  }

  void _setupOutputParsing() {
    // Parse stdout for VM Service URI and other info
    process.stdout.transform(const SystemEncoding().decoder).listen((line) {
      _outputBuffer.add(line); // Buffer for late listeners
      _outputController.add(line);
      _parseOutputLine(line);
    });

    // Forward stderr
    process.stderr.transform(const SystemEncoding().decoder).listen((line) {
      _errorBuffer.add(line); // Buffer for late listeners
      _errorController.add(line);
    });
  }

  void _setupProcessExitHandler() {
    process.exitCode.then((exitCode) {
      _isRunning = false;
      if (!_outputController.isClosed) {
        _outputController.add('Process exited with code: $exitCode');
      }

      // If startup hasn't completed yet, mark it as failed
      if (!_startupCompleter.isCompleted) {
        _startupCompleter.complete(
          StartupResult.failed(
            'Process exited with code $exitCode before startup completed',
          ),
        );
      }
    });
  }

  void _parseOutputLine(String line) {
    // Parse VM Service URI (e.g., "An Observatory debugger and profiler on iPhone 15 is available at: http://127.0.0.1:50123/...")
    if (line.contains('Observatory') || line.contains('VM Service')) {
      final uriMatch = RegExp(r'http://[^\s]+').firstMatch(line);
      if (uriMatch != null) {
        _vmServiceUri = uriMatch.group(0);

        // Connect to VM Service asynchronously
        _connectToVmService();

        // VM Service URI indicates successful startup
        if (!_startupCompleter.isCompleted) {
          _startupCompleter.complete(
            StartupResult.success(
              message:
                  'Flutter started successfully with VM Service at $_vmServiceUri',
            ),
          );
        }
      }
    }

    // Parse device ID from Flutter output
    if (line.contains('is available at:') || line.contains('Launching')) {
      final deviceMatch = RegExp(r'on ([^\s]+) is').firstMatch(line);
      if (deviceMatch != null) {
        _deviceId = deviceMatch.group(1);
      }
    }

    // Check for error indicators
    if (line.contains('Error:') ||
        line.contains('Exception:') ||
        line.contains('Failed to')) {
      if (!_startupCompleter.isCompleted) {
        _startupCompleter.complete(
          StartupResult.failed('Startup failed: $line'),
        );
      }
    }

    // Check for successful app startup indicators (Flutter run key commands)
    if (line.contains('Flutter run key commands') ||
        line.contains('To hot reload')) {
      if (!_startupCompleter.isCompleted) {
        _startupCompleter.complete(
          StartupResult.success(message: 'Flutter started successfully'),
        );
      }
    }
  }

  /// Connect to VM Service
  Future<void> _connectToVmService() async {
    if (_vmServiceUri == null || _vmService != null) return;

    try {
      // Convert http:// to ws:// for WebSocket connection
      final wsUri = _vmServiceUri!.replaceFirst('http://', 'ws://');
      _vmService = await vmServiceConnectUri(wsUri);

      // Create evaluator for this VM Service connection
      _evaluator = await VmServiceEvaluator.create(_vmService!);
    } catch (e) {
      // Connection failed
      _vmService = null;
      _evaluator = null;
    }
  }

  /// Take a screenshot of the Flutter app
  /// Returns PNG image data as bytes, or null if screenshot fails
  ///
  /// Tries the runtime_ai_dev_tools extension first, falls back to Flutter's built-in extension
  Future<List<int>?> screenshot() async {
    print('🔍 [FlutterInstance] screenshot() called for instance $id');

    if (!_isRunning) {
      print('❌ [FlutterInstance] Instance is not running');
      throw StateError('Instance is not running');
    }

    if (_vmService == null) {
      print('⚠️  [FlutterInstance] VM Service not connected, attempting to connect...');
      // Try to connect if not already connected
      await _connectToVmService();
      if (_vmService == null) {
        print('❌ [FlutterInstance] Failed to connect to VM Service');
        throw StateError('VM Service not available');
      }
      print('✅ [FlutterInstance] VM Service connected');
    }

    // Add a small delay as recommended by Flutter driver
    print('⏱️  [FlutterInstance] Waiting 500ms before screenshot...');
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Get isolate ID (required for service extension calls)
    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      print('❌ [FlutterInstance] No isolate ID available');
      throw StateError('No isolate ID available for service extension call');
    }

    // Call runtime_ai_dev_tools screenshot extension
    print('🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.screenshot');
    print('   Using isolateId: $isolateId');

    final response = await _vmService!.callServiceExtension(
      'ext.runtime_ai_dev_tools.screenshot',
      isolateId: isolateId,  // CRITICAL: Must include isolateId!
    );

    print('📥 [FlutterInstance] Received response from runtime_ai_dev_tools');
    print('   Response type: ${response.type}');
    print('   Response JSON keys: ${response.json?.keys.toList()}');

    // Extract and decode the base64 screenshot from extension format
    final json = response.json;
    if (json != null && json['status'] == 'success') {
      print('✅ [FlutterInstance] runtime_ai_dev_tools screenshot successful');

      // Extract and store devicePixelRatio if present
      final devicePixelRatio = json['devicePixelRatio'];
      if (devicePixelRatio != null && devicePixelRatio is num) {
        _lastDevicePixelRatio = devicePixelRatio.toDouble();
        print('   Device pixel ratio: $_lastDevicePixelRatio');
      }

      final imageBase64 = json['image'] as String?;
      if (imageBase64 != null) {
        final bytes = base64.decode(imageBase64);
        print('✅ [FlutterInstance] Screenshot decoded: ${bytes.length} bytes');
        return bytes;
      }
      throw Exception('No image data in response');
    }

    throw Exception('Screenshot failed: ${json?['status']}');
  }

  /// Simulate a tap at the given coordinates
  ///
  /// Tries the runtime_ai_dev_tools extension first (which includes visualization),
  /// falls back to VM Service evaluate approach for apps without the extension
  ///
  /// Returns true if successful, throws exception if failed
  Future<bool> tap(double x, double y) async {
    print('🔍 [FlutterInstance] tap() called at coordinates ($x, $y) for instance $id');

    if (!_isRunning) {
      print('❌ [FlutterInstance] Instance is not running');
      throw StateError('Flutter instance is not running');
    }

    if (_vmService == null) {
      print('⚠️  [FlutterInstance] VM Service not connected, attempting to connect...');
      await _connectToVmService();
      if (_vmService == null) {
        print('❌ [FlutterInstance] Failed to connect to VM Service');
        throw StateError('VM Service not available');
      }
      print('✅ [FlutterInstance] VM Service connected');
    }

    // Get isolate ID (required for service extension calls)
    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      print('❌ [FlutterInstance] No isolate ID available');
      throw StateError('No isolate ID available for service extension call');
    }

    // Try runtime_ai_dev_tools extension (includes tap visualization)
    print('🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.tap');
    print('   Parameters: x=$x, y=$y, isolateId=$isolateId');

    final response = await _vmService!.callServiceExtension(
      'ext.runtime_ai_dev_tools.tap',
      isolateId: isolateId,  // CRITICAL: Must include isolateId!
      args: {
        'x': x.toString(),
        'y': y.toString(),
      },
    );

    print('📥 [FlutterInstance] Received response from runtime_ai_dev_tools.tap');
    print('   Response type: ${response.type}');
    print('   Response JSON: ${response.json}');

    // Check if tap was successful
    final json = response.json;
    if (json != null && json['status'] == 'success') {
      print('✅ [FlutterInstance] Tap successful via runtime_ai_dev_tools');
      print('   Coordinates confirmed: x=${json['x']}, y=${json['y']}');
      return true;
    }

    throw Exception('Tap failed: ${json?['status']}');
  }

  /// Simulate typing text into the currently focused input
  ///
  /// Supports special keys: {backspace}, {enter}, {tab}, {escape}, {left}, {right}, {up}, {down}
  ///
  /// Returns true if successful, throws exception if failed
  Future<bool> type(String text) async {
    print('🔍 [FlutterInstance] type() called with text: "$text" for instance $id');

    if (!_isRunning) {
      print('❌ [FlutterInstance] Instance is not running');
      throw StateError('Flutter instance is not running');
    }

    if (_vmService == null) {
      print('⚠️  [FlutterInstance] VM Service not connected, attempting to connect...');
      await _connectToVmService();
      if (_vmService == null) {
        print('❌ [FlutterInstance] Failed to connect to VM Service');
        throw StateError('VM Service not available');
      }
      print('✅ [FlutterInstance] VM Service connected');
    }

    // Get isolate ID (required for service extension calls)
    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      print('❌ [FlutterInstance] No isolate ID available');
      throw StateError('No isolate ID available for service extension call');
    }

    // Call runtime_ai_dev_tools type extension
    print('🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.type');
    print('   Parameters: text=$text, isolateId=$isolateId');

    final response = await _vmService!.callServiceExtension(
      'ext.runtime_ai_dev_tools.type',
      isolateId: isolateId,
      args: {
        'text': text,
      },
    );

    print('📥 [FlutterInstance] Received response from runtime_ai_dev_tools.type');
    print('   Response type: ${response.type}');
    print('   Response JSON: ${response.json}');

    // Check if type was successful
    final json = response.json;
    if (json != null && json['status'] == 'success') {
      print('✅ [FlutterInstance] Type successful via runtime_ai_dev_tools');
      return true;
    }

    throw Exception('Type failed: ${json?['status']}');
  }

  /// Simulate a scroll/drag gesture
  ///
  /// Parameters:
  /// - startX, startY: Starting position in logical pixels
  /// - dx, dy: Relative scroll amount in logical pixels
  /// - durationMs: Duration of the scroll animation (default 300ms)
  ///
  /// Returns true if successful, throws exception if failed
  Future<bool> scroll({
    required double startX,
    required double startY,
    required double dx,
    required double dy,
    int? durationMs,
  }) async {
    print('🔍 [FlutterInstance] scroll() called for instance $id');
    print('   Start: ($startX, $startY), Delta: ($dx, $dy), Duration: ${durationMs}ms');

    if (!_isRunning) {
      print('❌ [FlutterInstance] Instance is not running');
      throw StateError('Flutter instance is not running');
    }

    if (_vmService == null) {
      print('⚠️  [FlutterInstance] VM Service not connected, attempting to connect...');
      await _connectToVmService();
      if (_vmService == null) {
        print('❌ [FlutterInstance] Failed to connect to VM Service');
        throw StateError('VM Service not available');
      }
      print('✅ [FlutterInstance] VM Service connected');
    }

    // Get isolate ID (required for service extension calls)
    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      print('❌ [FlutterInstance] No isolate ID available');
      throw StateError('No isolate ID available for service extension call');
    }

    // Call runtime_ai_dev_tools scroll extension
    print('🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.scroll');

    final args = <String, String>{
      'startX': startX.toString(),
      'startY': startY.toString(),
      'dx': dx.toString(),
      'dy': dy.toString(),
    };
    if (durationMs != null) {
      args['durationMs'] = durationMs.toString();
    }

    final response = await _vmService!.callServiceExtension(
      'ext.runtime_ai_dev_tools.scroll',
      isolateId: isolateId,
      args: args,
    );

    print('📥 [FlutterInstance] Received response from runtime_ai_dev_tools.scroll');
    print('   Response type: ${response.type}');
    print('   Response JSON: ${response.json}');

    // Check if scroll was successful
    final json = response.json;
    if (json != null && json['status'] == 'success') {
      print('✅ [FlutterInstance] Scroll successful via runtime_ai_dev_tools');
      return true;
    }

    throw Exception('Scroll failed: ${json?['status']}');
  }

  /// Perform hot reload
  Future<String> hotReload() async {
    if (!_isRunning) {
      throw StateError('Instance is not running');
    }

    // Send 'r' to trigger hot reload
    process.stdin.writeln('r');
    await process.stdin.flush();

    return 'Hot reload triggered';
  }

  /// Perform hot restart (full restart)
  Future<String> hotRestart() async {
    if (!_isRunning) {
      throw StateError('Instance is not running');
    }

    // Send 'R' to trigger hot restart
    process.stdin.writeln('R');
    await process.stdin.flush();

    return 'Hot restart triggered';
  }

  /// Stop the Flutter instance
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    // Clean up evaluator overlays
    await _evaluator?.dispose();

    // Send 'q' to gracefully quit
    try {
      process.stdin.writeln('q');
      await process.stdin.flush();

      // Wait up to 5 seconds for graceful shutdown
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // Force kill if graceful shutdown times out
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (e) {
      // If stdin write fails, force kill
      process.kill(ProcessSignal.sigkill);
    }

    _isRunning = false;
    await _outputController.close();
    await _errorController.close();
  }

  /// Get a summary of the instance state
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workingDirectory': workingDirectory,
      'command': command.join(' '),
      'startedAt': startedAt.toIso8601String(),
      'isRunning': _isRunning,
      'vmServiceUri': _vmServiceUri,
      'deviceId': _deviceId,
    };
  }
}
