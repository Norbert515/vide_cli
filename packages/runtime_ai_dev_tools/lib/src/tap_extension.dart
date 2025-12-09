import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'tap_visualization.dart';

/// Registers the tap service extension
void registerTapExtension() {
  print('🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.tap');

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.tap',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] tap extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');

      try {
        final xStr = parameters['x'];
        final yStr = parameters['y'];

        if (xStr == null || yStr == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required parameters: x and y',
          );
        }

        final x = double.tryParse(xStr);
        final y = double.tryParse(yStr);

        if (x == null || y == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Invalid x or y coordinate',
          );
        }

        await _simulateTap(x, y);

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'x': xStr,
            'y': yStr,
          }),
        );
      } catch (e, stackTrace) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to simulate tap: $e\n$stackTrace',
        );
      }
    },
  );
}

/// Simulates a tap at the specified coordinates
Future<void> _simulateTap(double x, double y) async {
  print('🎯 [RuntimeAiDevTools] _simulateTap called at ($x, $y)');

  try {
    final binding = WidgetsBinding.instance;
    final offset = Offset(x, y);

    // Show tap visualization first
    final rootContext = binding.rootElement;
    if (rootContext != null) {
      print('   Showing tap visualization overlay');
      try {
        TapVisualizationService().showTapAt(rootContext, x, y);
        print('   ✅ Visualization shown successfully');
      } catch (e) {
        print('   ⚠️  Visualization failed: $e');
        // Continue even if visualization fails
      }
    } else {
      print('   ⚠️  No root context available for visualization');
    }

    // Send pointer down event with minimal parameters (matching VM Service evaluator approach)
    print('   Sending PointerDownEvent at $offset');
    final downEvent = PointerDownEvent(position: offset);
    binding.handlePointerEvent(downEvent);
    print('   ✅ PointerDownEvent dispatched');

    // Wait 100ms for realistic tap duration
    print('   Waiting 100ms...');
    await Future.delayed(const Duration(milliseconds: 100));

    // Send pointer up event
    print('   Sending PointerUpEvent at $offset');
    final upEvent = PointerUpEvent(position: offset);
    binding.handlePointerEvent(upEvent);
    print('   ✅ PointerUpEvent dispatched');

    // Set persistent cursor so screenshots show where the tap occurred
    if (rootContext != null) {
      try {
        TapVisualizationService().setPersistentCursor(rootContext, x, y);
        print('   ✅ Persistent cursor set at ($x, $y)');
      } catch (e) {
        print('   ⚠️  Failed to set persistent cursor: $e');
        // Continue even if persistent cursor fails
      }
    }

    print('✅ [RuntimeAiDevTools] Tap simulation complete');
  } catch (e, stackTrace) {
    print('❌ [RuntimeAiDevTools] Tap simulation failed: $e');
    print('   Stack trace: $stackTrace');
    rethrow;
  }
}
