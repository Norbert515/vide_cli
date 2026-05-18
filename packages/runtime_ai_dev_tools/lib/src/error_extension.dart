import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Maximum number of errors to buffer to prevent memory issues
const int _maxErrorBufferSize = 100;

/// Error capture state singleton
class _ErrorCaptureState {
  _ErrorCaptureState._();
  static final instance = _ErrorCaptureState._();

  bool _enabled = false;
  final List<Map<String, dynamic>> _errors = [];

  /// Original Flutter error handler (chained)
  FlutterExceptionHandler? _originalFlutterOnError;

  /// Original platform dispatcher error handler (chained)
  /// Type: (Object error, StackTrace stack) -> bool
  bool Function(Object, StackTrace)? _originalPlatformOnError;

  bool get isEnabled => _enabled;

  void enable() {
    if (_enabled) return;

    // Chain with existing Flutter error handler
    _originalFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _captureFlutterError(details);
      // Call the original handler
      _originalFlutterOnError?.call(details);
    };

    // Chain with existing platform dispatcher error handler (async errors)
    _originalPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _capturePlatformError(error, stack);
      // Call the original handler if it exists, return its result
      // If no original handler, return false to allow the error to propagate
      return _originalPlatformOnError?.call(error, stack) ?? false;
    };

    _enabled = true;
    print('🔧 [RuntimeAiDevTools] Error capture enabled');
  }

  void disable() {
    if (!_enabled) return;

    // Restore original handlers
    FlutterError.onError = _originalFlutterOnError;
    PlatformDispatcher.instance.onError = _originalPlatformOnError;

    _originalFlutterOnError = null;
    _originalPlatformOnError = null;
    _enabled = false;
    print('🔧 [RuntimeAiDevTools] Error capture disabled');
  }

  void _captureFlutterError(FlutterErrorDetails details) {
    final errorInfo = <String, dynamic>{
      'type': 'FlutterError',
      'message': details.exceptionAsString(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'stackTrace': details.stack?.toString() ?? '',
    };

    // Add context if available
    if (details.context != null) {
      errorInfo['context'] = details.context!.toDescription();
    }

    // Add library if available
    if (details.library != null) {
      errorInfo['library'] = details.library;
    }

    _addError(errorInfo);
  }

  void _capturePlatformError(Object error, StackTrace stack) {
    final errorInfo = <String, dynamic>{
      'type': 'AsyncError',
      'message': error.toString(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'stackTrace': stack.toString(),
    };

    _addError(errorInfo);
  }

  void _addError(Map<String, dynamic> errorInfo) {
    // Enforce max buffer size
    if (_errors.length >= _maxErrorBufferSize) {
      _errors.removeAt(0); // Remove oldest error
    }
    _errors.add(errorInfo);
    print('📥 [RuntimeAiDevTools] Error captured: ${errorInfo['type']}');
  }

  List<Map<String, dynamic>> getErrors({bool clear = true}) {
    final result = List<Map<String, dynamic>>.from(_errors);
    if (clear) {
      _errors.clear();
    }
    return result;
  }

  int clearErrors() {
    final count = _errors.length;
    _errors.clear();
    return count;
  }

  int get errorCount => _errors.length;
}

/// Registers the error capture service extensions
///
/// This registers three extensions:
/// - ext.runtime_ai_dev_tools.enableErrorCapture - Enable/disable error capture
/// - ext.runtime_ai_dev_tools.getErrors - Get captured errors
/// - ext.runtime_ai_dev_tools.clearErrors - Clear the error buffer
void registerErrorExtension() {
  print('🔧 [RuntimeAiDevTools] Registering error capture service extensions');

  // Enable/disable error capture
  developer.registerExtension(
    'ext.runtime_ai_dev_tools.enableErrorCapture',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] enableErrorCapture extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');

      try {
        final enabledStr = parameters['enabled'] ?? 'true';
        final enabled = enabledStr.toLowerCase() == 'true';

        if (enabled) {
          _ErrorCaptureState.instance.enable();
        } else {
          _ErrorCaptureState.instance.disable();
        }

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'enabled': _ErrorCaptureState.instance.isEnabled,
          }),
        );
      } catch (e, stackTrace) {
        print('❌ [RuntimeAiDevTools] enableErrorCapture failed: $e');
        print('   Stack trace: $stackTrace');
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to enable/disable error capture: $e\n$stackTrace',
        );
      }
    },
  );

  // Get captured errors
  developer.registerExtension(
    'ext.runtime_ai_dev_tools.getErrors',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] getErrors extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');

      try {
        final clearStr = parameters['clear'] ?? 'true';
        final clear = clearStr.toLowerCase() == 'true';

        final errors = _ErrorCaptureState.instance.getErrors(clear: clear);

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'errors': errors,
            'count': errors.length,
          }),
        );
      } catch (e, stackTrace) {
        print('❌ [RuntimeAiDevTools] getErrors failed: $e');
        print('   Stack trace: $stackTrace');
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to get errors: $e\n$stackTrace',
        );
      }
    },
  );

  // Clear error buffer
  developer.registerExtension(
    'ext.runtime_ai_dev_tools.clearErrors',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] clearErrors extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');

      try {
        final cleared = _ErrorCaptureState.instance.clearErrors();

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'cleared': cleared,
          }),
        );
      } catch (e, stackTrace) {
        print('❌ [RuntimeAiDevTools] clearErrors failed: $e');
        print('   Stack trace: $stackTrace');
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to clear errors: $e\n$stackTrace',
        );
      }
    },
  );
}
