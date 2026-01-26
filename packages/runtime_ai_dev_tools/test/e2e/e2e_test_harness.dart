import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Test harness for E2E tests that manages a Flutter process and VM Service
/// connection.
///
/// Launches the test app, connects to its VM Service, discovers the main
/// isolate, and provides helper methods for calling service extensions.
class E2eTestHarness {
  Process? _process;
  VmService? _vmService;
  String? _isolateId;

  bool get isConnected => _vmService != null && _isolateId != null;

  VmService get vmService {
    if (_vmService == null) {
      throw StateError('VM Service not connected. Call start() first.');
    }
    return _vmService!;
  }

  String get isolateId {
    if (_isolateId == null) {
      throw StateError('Isolate not found. Call start() first.');
    }
    return _isolateId!;
  }

  /// Start the test app and connect to VM Service.
  ///
  /// [testAppDir] is the absolute path to the test app directory.
  /// [timeout] is the maximum time to wait for the app to start.
  Future<void> start({
    required String testAppDir,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    print('Starting Flutter test app from: $testAppDir');

    _process = await Process.start(
      'flutter',
      ['run', '-d', 'macos', '--no-hot'],
      workingDirectory: testAppDir,
    );

    final vmServiceUri = await _waitForVmServiceUri(timeout);
    print('VM Service URI: $vmServiceUri');

    // Convert http:// to ws:// for WebSocket connection
    final wsUri = vmServiceUri.replaceFirst('http://', 'ws://');
    print('Connecting to VM Service at: $wsUri');

    _vmService = await vmServiceConnectUri(wsUri);
    print('VM Service connected');

    // Find the main isolate
    await _findMainIsolate();
    print('Main isolate found: $_isolateId');

    // Wait for service extensions to register
    print('Waiting for service extensions to register...');
    await Future<void>.delayed(const Duration(seconds: 3));
    print('Harness ready');
  }

  /// Wait for the VM Service URI to appear in stdout.
  Future<String> _waitForVmServiceUri(Duration timeout) async {
    final completer = Completer<String>();
    final uriPattern = RegExp(r'http://[^\s]+');

    final stdoutSub = _process!.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      print('[FLUTTER] $line');
      if (line.contains('Observatory') || line.contains('VM Service')) {
        final match = uriPattern.firstMatch(line);
        if (match != null && !completer.isCompleted) {
          completer.complete(match.group(0)!);
        }
      }
    });

    _process!.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      print('[FLUTTER STDERR] $line');
    });

    // Also handle process exit before URI is found
    _process!.exitCode.then((exitCode) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Flutter process exited with code $exitCode before '
              'VM Service URI was found'),
        );
      }
    });

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      throw StateError(
        'Timed out waiting for VM Service URI after ${timeout.inSeconds}s',
      );
    } finally {
      await stdoutSub.cancel();
    }
  }

  /// Find the main isolate with a root library.
  Future<void> _findMainIsolate() async {
    final vm = await _vmService!.getVM();
    if (vm.isolates == null || vm.isolates!.isEmpty) {
      throw StateError('No isolates found in VM');
    }

    for (final isolateRef in vm.isolates!) {
      if (isolateRef.id == null) continue;

      final isolate = await _vmService!.getIsolate(isolateRef.id!);

      // Skip isolates that are exiting
      final pauseEvent = isolate.pauseEvent;
      if (pauseEvent != null) {
        final kind = pauseEvent.kind;
        if (kind == EventKind.kPauseExit || kind == EventKind.kIsolateExit) {
          continue;
        }
      }

      if (isolate.rootLib != null) {
        _isolateId = isolateRef.id!;
        return;
      }
    }

    throw StateError('No runnable isolate with root library found');
  }

  /// Call a service extension and return the parsed JSON response.
  Future<Map<String, dynamic>> callExtension(
    String method, {
    Map<String, String>? args,
  }) async {
    final response = await vmService.callServiceExtension(
      method,
      isolateId: isolateId,
      args: args,
    );

    final json = response.json;
    if (json == null) {
      throw StateError('Extension $method returned null response');
    }

    return _deepConvertJson(json);
  }

  /// Deep-convert a JSON map so all nested maps become Map<String, dynamic>.
  /// The VM Service may return nested maps with opaque runtime types that
  /// fail direct `as Map<String, dynamic>` casts.
  static Map<String, dynamic> _deepConvertJson(dynamic input) {
    if (input is! Map) {
      throw StateError('Expected Map, got ${input.runtimeType}');
    }
    final result = <String, dynamic>{};
    for (final key in input.keys) {
      final value = input[key];
      result[key.toString()] = _convertValue(value);
    }
    return result;
  }

  static dynamic _convertValue(dynamic value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final key in value.keys) {
        result[key.toString()] = _convertValue(value[key]);
      }
      return result;
    } else if (value is List) {
      return value.map(_convertValue).toList();
    }
    return value;
  }

  /// Call a service extension and assert that status == 'success'.
  Future<Map<String, dynamic>> callExtensionExpectSuccess(
    String method, {
    Map<String, String>? args,
  }) async {
    final result = await callExtension(method, args: args);
    if (result['status'] != 'success') {
      throw StateError(
        'Extension $method returned status "${result['status']}" '
        'instead of "success". Response: $result',
      );
    }
    return result;
  }

  /// Stop the Flutter process gracefully.
  Future<void> stop() async {
    print('Stopping E2E test harness...');

    // Dispose VM Service
    try {
      await _vmService?.dispose();
    } catch (_) {}
    _vmService = null;
    _isolateId = null;

    // Send 'q' to gracefully quit Flutter
    final process = _process;
    if (process != null) {
      try {
        process.stdin.writeln('q');
        await process.stdin.flush();
      } catch (_) {}

      // Wait for exit with timeout, fallback to SIGKILL
      try {
        await process.exitCode.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Graceful shutdown timed out, killing process...');
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
    }
    _process = null;

    print('E2E test harness stopped');
  }
}
