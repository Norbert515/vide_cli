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

  /// Timeout duration for VM Service operations
  static const _vmServiceTimeout = Duration(seconds: 30);

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
      print(
        '⚠️  [FlutterInstance] VM Service not connected, attempting to connect...',
      );
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
    print(
      '🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.screenshot',
    );
    print('   Using isolateId: $isolateId');

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.screenshot',
          isolateId: isolateId, // CRITICAL: Must include isolateId!
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'Screenshot timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
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
    print(
      '🔍 [FlutterInstance] tap() called at coordinates ($x, $y) for instance $id',
    );

    if (!_isRunning) {
      print('❌ [FlutterInstance] Instance is not running');
      throw StateError('Flutter instance is not running');
    }

    if (_vmService == null) {
      print(
        '⚠️  [FlutterInstance] VM Service not connected, attempting to connect...',
      );
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
    print(
      '🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.tap',
    );
    print('   Parameters: x=$x, y=$y, isolateId=$isolateId');

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.tap',
          isolateId: isolateId, // CRITICAL: Must include isolateId!
          args: {'x': x.toString(), 'y': y.toString()},
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'Tap timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    print(
      '📥 [FlutterInstance] Received response from runtime_ai_dev_tools.tap',
    );
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
    print(
      '🔍 [FlutterInstance] type() called with text: "$text" for instance $id',
    );

    if (!_isRunning) {
      print('❌ [FlutterInstance] Instance is not running');
      throw StateError('Flutter instance is not running');
    }

    if (_vmService == null) {
      print(
        '⚠️  [FlutterInstance] VM Service not connected, attempting to connect...',
      );
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
    print(
      '🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.type',
    );
    print('   Parameters: text=$text, isolateId=$isolateId');

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.type',
          isolateId: isolateId,
          args: {'text': text},
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'Type timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    print(
      '📥 [FlutterInstance] Received response from runtime_ai_dev_tools.type',
    );
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
    print(
      '   Start: ($startX, $startY), Delta: ($dx, $dy), Duration: ${durationMs}ms',
    );

    if (!_isRunning) {
      print('❌ [FlutterInstance] Instance is not running');
      throw StateError('Flutter instance is not running');
    }

    if (_vmService == null) {
      print(
        '⚠️  [FlutterInstance] VM Service not connected, attempting to connect...',
      );
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
    print(
      '🔧 [FlutterInstance] Attempting to call ext.runtime_ai_dev_tools.scroll',
    );

    final args = <String, String>{
      'startX': startX.toString(),
      'startY': startY.toString(),
      'dx': dx.toString(),
      'dy': dy.toString(),
    };
    if (durationMs != null) {
      args['durationMs'] = durationMs.toString();
    }

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.scroll',
          isolateId: isolateId,
          args: args,
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'Scroll timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    print(
      '📥 [FlutterInstance] Received response from runtime_ai_dev_tools.scroll',
    );
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

  /// Get widget information at the specified screen coordinates
  ///
  /// Returns a map containing:
  /// - widgets: List of widgets at the position (innermost first)
  /// - Each widget has: type, key, bounds, creationLocation (if available), text (for Text widgets)
  ///
  /// Coordinates should be in logical pixels (not physical/device pixels).
  Future<Map<String, dynamic>> getWidgetInfo(double x, double y) async {
    print('🔍 [FlutterInstance] Getting widget info at ($x, $y)');

    if (_vmService == null) {
      throw StateError('VM Service not connected');
    }

    // Get isolate ID (required for service extension calls)
    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      print('❌ [FlutterInstance] No isolate ID available');
      throw StateError('No isolate ID available for service extension call');
    }

    print(
      '🔧 [FlutterInstance] Calling ext.runtime_ai_dev_tools.getWidgetInfo',
    );
    print('   Parameters: x=$x, y=$y, isolateId=$isolateId');

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.getWidgetInfo',
          isolateId: isolateId,
          args: {'x': x.toString(), 'y': y.toString()},
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'getWidgetInfo timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    print(
      '📥 [FlutterInstance] Received response from runtime_ai_dev_tools.getWidgetInfo',
    );
    print('   Response type: ${response.type}');

    final json = response.json;
    if (json == null) {
      throw Exception('getWidgetInfo returned null response');
    }

    if (json['status'] == 'success') {
      print('✅ [FlutterInstance] getWidgetInfo successful');
      return Map<String, dynamic>.from(json);
    }

    throw Exception('getWidgetInfo failed: ${json['error'] ?? json['status']}');
  }

  /// Move the cursor to the specified screen coordinates
  ///
  /// Coordinates should be in logical pixels (not physical/device pixels).
  /// Returns true if successful.
  Future<bool> moveCursor(double x, double y) async {
    print('🎯 [FlutterInstance] Moving cursor to ($x, $y)');

    if (_vmService == null) {
      throw StateError('VM Service not connected');
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.moveCursor',
          isolateId: isolateId,
          args: {'x': x.toString(), 'y': y.toString()},
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'moveCursor timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    final json = response.json;
    if (json != null && json['status'] == 'success') {
      print('✅ [FlutterInstance] Cursor moved to ($x, $y)');
      return true;
    }

    throw Exception('moveCursor failed: ${json?['status']}');
  }

  /// Get the current cursor position
  ///
  /// Returns the position in logical pixels, or null if no cursor is set.
  Future<({double x, double y})?> getCursorPosition() async {
    print('🔍 [FlutterInstance] Getting cursor position');

    if (_vmService == null) {
      throw StateError('VM Service not connected');
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.getCursorPosition',
          isolateId: isolateId,
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'getCursorPosition timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    final json = response.json;
    if (json == null) {
      throw Exception('getCursorPosition returned null response');
    }

    if (json['status'] == 'success') {
      if (json['hasPosition'] == true) {
        final x = (json['x'] as num).toDouble();
        final y = (json['y'] as num).toDouble();
        print('✅ [FlutterInstance] Cursor position: ($x, $y)');
        return (x: x, y: y);
      } else {
        print('ℹ️  [FlutterInstance] No cursor position set');
        return null;
      }
    }

    throw Exception(
      'getCursorPosition failed: ${json['error'] ?? json['status']}',
    );
  }

  /// Get all actionable elements in the current UI.
  ///
  /// Returns a list of interactive elements (buttons, text fields, etc.)
  /// that can be interacted with by ID using [tapElement].
  ///
  /// Each element contains:
  /// - id: Unique identifier for interaction (e.g., "button_0", "textfield_1")
  /// - type: Element type (button, textfield, checkbox, etc.)
  /// - label: Text label or content (if available)
  /// - Additional type-specific properties (hint, checked, enabled, etc.)
  Future<Map<String, dynamic>> getActionableElements() async {
    print('🔍 [FlutterInstance] Getting actionable elements');

    if (_vmService == null) {
      throw StateError('VM Service not connected');
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    print(
      '🔧 [FlutterInstance] Calling ext.runtime_ai_dev_tools.getActionableElements',
    );

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.getActionableElements',
          isolateId: isolateId,
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'getActionableElements timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    print(
      '📥 [FlutterInstance] Received response from runtime_ai_dev_tools.getActionableElements',
    );

    final json = response.json;
    if (json == null) {
      throw Exception('getActionableElements returned null response');
    }

    if (json['status'] == 'success') {
      final elements = json['elements'] as List<dynamic>? ?? [];
      print('✅ [FlutterInstance] Found ${elements.length} actionable elements');
      return Map<String, dynamic>.from(json);
    }

    throw Exception(
      'getActionableElements failed: ${json['error'] ?? json['status']}',
    );
  }

  /// Tap an element by its ID.
  ///
  /// The ID must be from a previous call to [getActionableElements].
  /// This internally looks up the element's coordinates and performs the tap.
  ///
  /// Returns true if successful, throws exception if element not found.
  Future<bool> tapElement(String elementId) async {
    print('🎯 [FlutterInstance] Tapping element: $elementId');

    if (_vmService == null) {
      throw StateError('VM Service not connected');
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    // First, look up the element's coordinates
    print('🔧 [FlutterInstance] Looking up element coordinates');
    final lookupResponse = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.tapElement',
          isolateId: isolateId,
          args: {'id': elementId},
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'tapElement lookup timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    final lookupJson = lookupResponse.json;
    if (lookupJson == null || lookupJson['status'] != 'success') {
      throw Exception(
        'Element not found: $elementId. Call getActionableElements first to refresh the registry.',
      );
    }

    // Get coordinates and tap
    final x = (lookupJson['x'] as num).toDouble();
    final y = (lookupJson['y'] as num).toDouble();
    print('   Found element at ($x, $y), performing tap...');

    return tap(x, y);
  }

  /// Perform hot reload using the VM Service
  ///
  /// Calls the 'reloadSources' service registered by Flutter Tools.
  /// This is more reliable than sending 'r' to stdin and parsing output.
  Future<String> hotReload() async {
    if (!_isRunning) {
      throw StateError('Instance is not running');
    }

    if (_vmService == null) {
      throw StateError('VM Service not connected');
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available');
    }

    print('🔄 [FlutterInstance] Hot reload via VM Service...');

    try {
      // Call the reloadSources service registered by Flutter Tools
      // The service name format is 's<number>.reloadSources' where number is the client ID
      // We need to find the registered service first
      final vm = await _vmService!.getVM();

      // Look for the reloadSources service in registered services
      String? reloadServiceName;
      if (vm.json != null && vm.json!['_registeredServices'] != null) {
        final services =
            vm.json!['_registeredServices'] as Map<String, dynamic>?;
        if (services != null) {
          for (final entry in services.entries) {
            if (entry.key == 'reloadSources') {
              reloadServiceName = entry.value as String?;
              break;
            }
          }
        }
      }

      if (reloadServiceName != null) {
        // Call the Flutter Tools reloadSources service
        print('🔄 [FlutterInstance] Calling $reloadServiceName service...');
        final result = await _vmService!
            .callMethod(reloadServiceName, args: {'isolateId': isolateId})
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Hot reload timed out'),
            );
        print(
          '✅ [FlutterInstance] Hot reload completed via service: ${result.json}',
        );
        return 'Hot reload completed';
      }

      // Fallback: Use stdin (works for all platforms including web)
      print(
        '⚠️  [FlutterInstance] reloadSources service not found, using stdin fallback',
      );
      process.stdin.writeln('r');
      await process.stdin.flush();

      // Wait a bit for the reload to complete
      await Future.delayed(const Duration(milliseconds: 1500));

      // Try to trigger reassemble to ensure widgets rebuild
      try {
        await _vmService!.callServiceExtension(
          'ext.flutter.reassemble',
          isolateId: isolateId,
        );
      } catch (e) {
        // Reassemble might not be available, that's ok
        print('⚠️  [FlutterInstance] Reassemble extension not available: $e');
      }

      print('✅ [FlutterInstance] Hot reload triggered via stdin');
      return 'Hot reload completed';
    } catch (e) {
      print('❌ [FlutterInstance] Hot reload failed: $e');
      rethrow;
    }
  }

  /// Perform hot restart (full restart) using the VM Service
  ///
  /// Calls the 'hotRestart' service registered by Flutter Tools.
  Future<String> hotRestart() async {
    if (!_isRunning) {
      throw StateError('Instance is not running');
    }

    if (_vmService == null) {
      throw StateError('VM Service not connected');
    }

    print('🔄 [FlutterInstance] Hot restart via VM Service...');

    try {
      // Look for the hotRestart service registered by Flutter Tools
      final vm = await _vmService!.getVM();

      String? restartServiceName;
      if (vm.json != null && vm.json!['_registeredServices'] != null) {
        final services =
            vm.json!['_registeredServices'] as Map<String, dynamic>?;
        if (services != null) {
          for (final entry in services.entries) {
            if (entry.key == 'hotRestart') {
              restartServiceName = entry.value as String?;
              break;
            }
          }
        }
      }

      if (restartServiceName != null) {
        // Call the Flutter Tools hotRestart service
        print('🔄 [FlutterInstance] Calling $restartServiceName service...');
        await _vmService!
            .callMethod(restartServiceName, args: {})
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Hot restart timed out'),
            );
        print('✅ [FlutterInstance] Hot restart completed via service');
      } else {
        // Fallback: send 'R' to stdin (less reliable but works)
        print(
          '⚠️  [FlutterInstance] hotRestart service not found, using stdin fallback',
        );
        process.stdin.writeln('R');
        await process.stdin.flush();
        // Wait for restart to complete
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      // Hot restart creates a new isolate, refresh the evaluator
      await _refreshEvaluator();

      return 'Hot restart completed';
    } catch (e) {
      print('❌ [FlutterInstance] Hot restart failed: $e');
      rethrow;
    }
  }

  /// Refresh the evaluator to get a fresh isolate ID
  ///
  /// This is needed after hot reload/restart because the isolate may change.
  /// After creating the evaluator, we verify it works by fetching the isolate.
  Future<void> _refreshEvaluator() async {
    if (_vmService == null) return;

    // Clear the old evaluator
    _evaluator = null;

    // Retry a few times since the new isolate may not be immediately available
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        _evaluator = await VmServiceEvaluator.create(_vmService!);
        if (_evaluator != null) {
          // Verify the evaluator works by fetching the isolate
          try {
            await _vmService!.getIsolate(_evaluator!.isolateId);
            print(
              '✅ [FlutterInstance] Evaluator refreshed and verified with isolate: ${_evaluator!.isolateId}',
            );
            return;
          } catch (e) {
            print(
              '⚠️  [FlutterInstance] Evaluator verification failed on attempt ${attempt + 1}: $e',
            );
            _evaluator = null;
            // Continue retrying
          }
        }
      } catch (e) {
        print(
          '⚠️  [FlutterInstance] Evaluator refresh attempt ${attempt + 1} failed: $e',
        );
      }

      // Wait before retrying
      await Future.delayed(const Duration(milliseconds: 500));
    }

    print('❌ [FlutterInstance] Failed to refresh evaluator after 5 attempts');
  }

  /// Stop the Flutter instance
  ///
  /// Performs cleanup in this order:
  /// 1. Dispose evaluator overlays
  /// 2. Disconnect VM Service
  /// 3. Send 'q' to gracefully quit
  /// 4. Wait for process to exit (with timeout)
  /// 5. Force kill if graceful shutdown fails
  /// 6. Close stream controllers
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    // Mark as not running early to prevent concurrent operations
    _isRunning = false;

    // Step 1: Clean up evaluator overlays (best effort)
    try {
      await _evaluator?.dispose().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          // Evaluator cleanup timed out, continue with shutdown
        },
      );
    } catch (e) {
      // Evaluator cleanup failed, continue with shutdown
    }
    _evaluator = null;

    // Step 2: Disconnect VM Service (best effort)
    try {
      await _vmService?.dispose().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          // VM Service disconnect timed out, continue with shutdown
        },
      );
    } catch (e) {
      // VM Service disconnect failed, continue with shutdown
    }
    _vmService = null;

    // Step 3 & 4: Send 'q' to gracefully quit and wait for exit
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
      // If stdin write fails or any other error, force kill
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {
        // Process may already be dead, ignore
      }
    }

    // Step 5: Close stream controllers safely
    if (!_outputController.isClosed) {
      await _outputController.close();
    }
    if (!_errorController.isClosed) {
      await _errorController.close();
    }
  }

  /// Set the device size for responsive testing
  ///
  /// Uses MediaQuery override to simulate different device sizes.
  /// The app will respond to breakpoints as if it was running on the target device.
  ///
  /// Parameters:
  /// - width: Logical width in pixels
  /// - height: Logical height in pixels
  /// - devicePixelRatio: Device pixel ratio (optional, default 1.0)
  /// - showFrame: Whether to show a visual device frame (default true)
  /// - preset: Named preset (e.g., 'iphone-14', 'ipad-pro-11') - overrides width/height
  ///
  /// Returns the applied settings.
  Future<Map<String, dynamic>> setDeviceSize({
    double? width,
    double? height,
    double? devicePixelRatio,
    bool showFrame = true,
    String? preset,
  }) async {
    print('📱 [FlutterInstance] Setting device size for instance $id');

    if (_vmService == null) {
      throw StateError('VM Service not connected');
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    final args = <String, String>{
      'showFrame': showFrame.toString(),
    };

    if (preset != null) {
      args['preset'] = preset;
      print('   Using preset: $preset');
    } else if (width != null && height != null) {
      args['width'] = width.toString();
      args['height'] = height.toString();
      if (devicePixelRatio != null) {
        args['devicePixelRatio'] = devicePixelRatio.toString();
      }
      print('   Setting size to ${width}x$height @ ${devicePixelRatio ?? 1.0}x');
    } else {
      throw ArgumentError(
        'Either preset or width+height must be provided',
      );
    }

    print(
      '🔧 [FlutterInstance] Calling ext.runtime_ai_dev_tools.setDeviceSize',
    );

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.setDeviceSize',
          isolateId: isolateId,
          args: args,
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'setDeviceSize timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    print(
      '📥 [FlutterInstance] Received response from setDeviceSize',
    );

    final json = response.json;
    if (json == null) {
      throw Exception('setDeviceSize returned null response');
    }

    if (json['status'] == 'success') {
      print('✅ [FlutterInstance] Device size set successfully');
      return Map<String, dynamic>.from(json);
    }

    throw Exception('setDeviceSize failed: ${json['error'] ?? json['status']}');
  }

  /// Reset the device size to native
  ///
  /// Clears any device size override and returns to the native device size.
  Future<void> resetDeviceSize() async {
    print('📱 [FlutterInstance] Resetting device size for instance $id');

    if (_vmService == null) {
      throw StateError('VM Service not connected');
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    print(
      '🔧 [FlutterInstance] Calling ext.runtime_ai_dev_tools.resetDeviceSize',
    );

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.resetDeviceSize',
          isolateId: isolateId,
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'resetDeviceSize timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    print(
      '📥 [FlutterInstance] Received response from resetDeviceSize',
    );

    final json = response.json;
    if (json == null) {
      throw Exception('resetDeviceSize returned null response');
    }

    if (json['status'] == 'success') {
      print('✅ [FlutterInstance] Device size reset to native');
      return;
    }

    throw Exception(
      'resetDeviceSize failed: ${json['error'] ?? json['status']}',
    );
  }

  /// Get the current device size settings
  ///
  /// Returns the current device size settings, or null if using native size.
  Future<Map<String, dynamic>> getDeviceSize() async {
    print('📱 [FlutterInstance] Getting device size for instance $id');

    if (_vmService == null) {
      throw StateError('VM Service not connected');
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    print(
      '🔧 [FlutterInstance] Calling ext.runtime_ai_dev_tools.getDeviceSize',
    );

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.getDeviceSize',
          isolateId: isolateId,
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'getDeviceSize timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    print(
      '📥 [FlutterInstance] Received response from getDeviceSize',
    );

    final json = response.json;
    if (json == null) {
      throw Exception('getDeviceSize returned null response');
    }

    if (json['status'] == 'success') {
      print('✅ [FlutterInstance] Got device size');
      return Map<String, dynamic>.from(json);
    }

    throw Exception('getDeviceSize failed: ${json['error'] ?? json['status']}');
  }

  /// Get the current navigation state from the running Flutter app
  ///
  /// Returns information about routes, navigation stack, and modal routes.
  /// Requires runtime_ai_dev_tools to be injected into the app.
  Future<Map<String, dynamic>> getNavigationState() async {
    print('🔍 [FlutterInstance] Getting navigation state for instance $id');

    if (!_isRunning) {
      throw StateError('Flutter instance is not running');
    }

    if (_vmService == null) {
      await _connectToVmService();
      if (_vmService == null) {
        throw StateError('VM Service not available');
      }
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    print(
      '🔧 [FlutterInstance] Calling ext.runtime_ai_dev_tools.getNavigationState',
    );

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.getNavigationState',
          isolateId: isolateId,
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'getNavigationState timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    print(
      '📥 [FlutterInstance] Received response from runtime_ai_dev_tools.getNavigationState',
    );

    final json = response.json;
    if (json == null) {
      throw Exception('getNavigationState returned null response');
    }

    if (json['status'] == 'success') {
      print('✅ [FlutterInstance] Navigation state retrieved successfully');
      return Map<String, dynamic>.from(json);
    }

    throw Exception(
      'getNavigationState failed: ${json['error'] ?? json['status']}',
    );
  }

  /// Enable or disable error capture in the running Flutter app
  ///
  /// When enabled, Flutter framework errors and async errors are captured
  /// and can be retrieved via [getErrors].
  Future<bool> enableErrorCapture({bool enabled = true}) async {
    print(
      '🔧 [FlutterInstance] ${enabled ? "Enabling" : "Disabling"} error capture for instance $id',
    );

    if (!_isRunning) {
      throw StateError('Flutter instance is not running');
    }

    if (_vmService == null) {
      await _connectToVmService();
      if (_vmService == null) {
        throw StateError('VM Service not available');
      }
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.enableErrorCapture',
          isolateId: isolateId,
          args: {'enabled': enabled.toString()},
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'enableErrorCapture timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    final json = response.json;
    if (json != null && json['status'] == 'success') {
      print(
        '✅ [FlutterInstance] Error capture ${enabled ? "enabled" : "disabled"}',
      );
      return json['enabled'] as bool? ?? enabled;
    }

    throw Exception('enableErrorCapture failed: ${json?['status']}');
  }

  /// Get captured errors from the running Flutter app
  ///
  /// Returns a list of errors that have been captured since error capture
  /// was enabled. By default, clears the error buffer after retrieval.
  Future<Map<String, dynamic>> getErrors({bool clear = true}) async {
    print('🔍 [FlutterInstance] Getting errors for instance $id');

    if (!_isRunning) {
      throw StateError('Flutter instance is not running');
    }

    if (_vmService == null) {
      await _connectToVmService();
      if (_vmService == null) {
        throw StateError('VM Service not available');
      }
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.getErrors',
          isolateId: isolateId,
          args: {'clear': clear.toString()},
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'getErrors timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    final json = response.json;
    if (json != null && json['status'] == 'success') {
      final count = json['count'] as int? ?? 0;
      print('✅ [FlutterInstance] Retrieved $count errors');
      return Map<String, dynamic>.from(json);
    }

    throw Exception('getErrors failed: ${json?['status']}');
  }

  /// Clear the error buffer in the running Flutter app
  Future<int> clearErrors() async {
    print('🔍 [FlutterInstance] Clearing errors for instance $id');

    if (!_isRunning) {
      throw StateError('Flutter instance is not running');
    }

    if (_vmService == null) {
      await _connectToVmService();
      if (_vmService == null) {
        throw StateError('VM Service not available');
      }
    }

    final isolateId = _evaluator?.isolateId;
    if (isolateId == null) {
      throw StateError('No isolate ID available for service extension call');
    }

    final response = await _vmService!
        .callServiceExtension(
          'ext.runtime_ai_dev_tools.clearErrors',
          isolateId: isolateId,
        )
        .timeout(
          _vmServiceTimeout,
          onTimeout: () => throw TimeoutException(
            'clearErrors timed out after ${_vmServiceTimeout.inSeconds}s',
          ),
        );

    final json = response.json;
    if (json != null && json['status'] == 'success') {
      final cleared = json['cleared'] as int? ?? 0;
      print('✅ [FlutterInstance] Cleared $cleared errors');
      return cleared;
    }

    throw Exception('clearErrors failed: ${json?['status']}');
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
