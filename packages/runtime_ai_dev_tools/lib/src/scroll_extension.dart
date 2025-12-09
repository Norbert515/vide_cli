import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'tap_visualization.dart';

/// Registers the scroll service extension
void registerScrollExtension() {
  print('🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.scroll');

  developer.registerExtension(
    'ext.runtime_ai_dev_tools.scroll',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] scroll extension called');
      print('   Method: $method');
      print('   Parameters: $parameters');

      try {
        final startXStr = parameters['startX'];
        final startYStr = parameters['startY'];
        final dxStr = parameters['dx'];
        final dyStr = parameters['dy'];
        final durationMsStr = parameters['durationMs'];

        if (startXStr == null || startYStr == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required parameters: startX and startY',
          );
        }

        if (dxStr == null || dyStr == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required parameters: dx and dy',
          );
        }

        final startX = double.tryParse(startXStr);
        final startY = double.tryParse(startYStr);
        final dx = double.tryParse(dxStr);
        final dy = double.tryParse(dyStr);

        if (startX == null || startY == null || dx == null || dy == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Invalid coordinate values',
          );
        }

        final durationMs = durationMsStr != null ? int.tryParse(durationMsStr) : 300;
        final duration = Duration(milliseconds: durationMs ?? 300);

        await _simulateScroll(
          startX: startX,
          startY: startY,
          dx: dx,
          dy: dy,
          duration: duration,
        );

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'startX': startX,
            'startY': startY,
            'dx': dx,
            'dy': dy,
            'durationMs': duration.inMilliseconds,
          }),
        );
      } catch (e, stackTrace) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to simulate scroll: $e\n$stackTrace',
        );
      }
    },
  );
}

/// Simulates a scroll/drag gesture from start position with given delta
Future<void> _simulateScroll({
  required double startX,
  required double startY,
  required double dx,
  required double dy,
  required Duration duration,
}) async {
  print('📜 [RuntimeAiDevTools] _simulateScroll called');
  print('   Start: ($startX, $startY)');
  print('   Delta: ($dx, $dy)');
  print('   Duration: ${duration.inMilliseconds}ms');

  final binding = WidgetsBinding.instance;
  final endX = startX + dx;
  final endY = startY + dy;

  // Show scroll visualization
  final rootContext = binding.rootElement;
  if (rootContext != null) {
    print('   Showing scroll visualization');
    try {
      TapVisualizationService().showScrollPath(
        rootContext,
        Offset(startX, startY),
        Offset(endX, endY),
        duration,
      );
    } catch (e) {
      print('   ⚠️  Scroll visualization failed: $e');
      // Continue even if visualization fails
    }
  }

  // Calculate steps based on duration (target ~16ms per step for smooth animation)
  final steps = (duration.inMilliseconds / 16).round().clamp(5, 60);
  final stepDelay = Duration(milliseconds: duration.inMilliseconds ~/ steps);

  print('   Steps: $steps, Step delay: ${stepDelay.inMilliseconds}ms');

  // Pointer down at start
  print('   Sending PointerDownEvent at ($startX, $startY)');
  binding.handlePointerEvent(PointerDownEvent(
    position: Offset(startX, startY),
  ));

  // Move through interpolated positions
  for (var i = 1; i <= steps; i++) {
    await Future.delayed(stepDelay);

    final progress = i / steps;
    final currentX = startX + dx * progress;
    final currentY = startY + dy * progress;

    binding.handlePointerEvent(PointerMoveEvent(
      position: Offset(currentX, currentY),
      delta: Offset(dx / steps, dy / steps),
    ));
  }

  // Pointer up at end
  print('   Sending PointerUpEvent at ($endX, $endY)');
  binding.handlePointerEvent(PointerUpEvent(
    position: Offset(endX, endY),
  ));

  // Set persistent indicator at end position for screenshots
  if (rootContext != null) {
    try {
      TapVisualizationService().setScrollEndIndicator(
        rootContext,
        Offset(startX, startY),
        Offset(endX, endY),
      );
    } catch (e) {
      print('   ⚠️  Failed to set scroll end indicator: $e');
    }
  }

  print('✅ [RuntimeAiDevTools] Scroll simulation complete');
}
