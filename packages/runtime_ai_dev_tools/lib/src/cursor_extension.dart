import 'dart:convert';
import 'dart:developer' as developer;
import 'tap_visualization.dart';

/// Registers cursor-related service extensions
///
/// - ext.runtime_ai_dev_tools.moveCursor - Move the cursor to a position
/// - ext.runtime_ai_dev_tools.getCursorPosition - Get current cursor position
void registerCursorExtension() {
  print('🔧 [RuntimeAiDevTools] Registering cursor extensions');

  // Move cursor extension
  developer.registerExtension(
    'ext.runtime_ai_dev_tools.moveCursor',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] moveCursor extension called');
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

        // Set the cursor position (without requiring BuildContext for overlay)
        TapVisualizationService().setCursorPosition(x, y);

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'x': x,
            'y': y,
          }),
        );
      } catch (e, stackTrace) {
        print('❌ [RuntimeAiDevTools] moveCursor failed: $e');
        print('   Stack trace: $stackTrace');
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to move cursor: $e',
        );
      }
    },
  );

  // Get cursor position extension
  developer.registerExtension(
    'ext.runtime_ai_dev_tools.getCursorPosition',
    (String method, Map<String, String> parameters) async {
      print('📥 [RuntimeAiDevTools] getCursorPosition extension called');

      try {
        final position = TapVisualizationService().cursorPosition;

        if (position == null) {
          return developer.ServiceExtensionResponse.result(
            json.encode({
              'status': 'success',
              'hasPosition': false,
              'message': 'No cursor position set. Use moveCursor or tap first.',
            }),
          );
        }

        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'hasPosition': true,
            'x': position.dx,
            'y': position.dy,
          }),
        );
      } catch (e, stackTrace) {
        print('❌ [RuntimeAiDevTools] getCursorPosition failed: $e');
        print('   Stack trace: $stackTrace');
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to get cursor position: $e',
        );
      }
    },
  );

  print('✅ [RuntimeAiDevTools] Cursor extensions registered');
}
