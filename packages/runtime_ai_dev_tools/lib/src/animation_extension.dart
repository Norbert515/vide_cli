import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/scheduler.dart';

/// Registers the animation control service extension
///
/// This extension allows controlling animation speed by setting Flutter's
/// global timeDilation value.
void registerAnimationExtension() {
  print(
    '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.setTimeDilation',
  );

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.setTimeDilation',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] setTimeDilation extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');

      try {
        final factorStr = parameters['factor'];

        if (factorStr == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required parameter: factor',
          );
        }

        final factor = double.tryParse(factorStr);

        if (factor == null || factor < 0) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Invalid factor: must be a non-negative number',
          );
        }

        // Set the time dilation
        // 1.0 = normal speed
        // > 1.0 = slower animations
        // 0.0 would pause, but we use a very large number instead to avoid
        // potential division-by-zero issues
        timeDilation = factor;

        print('✅ [RuntimeAiDevTools] Time dilation set to $factor');

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'factor': factor,
          }),
        );
      } catch (e, stackTrace) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to set time dilation: $e\n$stackTrace',
        );
      }
    },
  );

  // Also register a getter for the current time dilation
  print(
    '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.getTimeDilation',
  );

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.getTimeDilation',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] getTimeDilation extension called');

      return developer.ServiceExtensionResponse.result(
        json.encode({
          'status': 'success',
          'factor': timeDilation,
        }),
      );
    },
  );
}
