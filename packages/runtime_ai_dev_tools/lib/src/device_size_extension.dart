import 'dart:convert';
import 'dart:developer' as developer;
import 'device_presets.dart';
import 'device_size_state.dart';

/// Registers the device size service extensions
void registerDeviceSizeExtension() {
  print(
    '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.setDeviceSize',
  );
  print(
    '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.resetDeviceSize',
  );
  print(
    '🔧 [RuntimeAiDevTools] Registering ext.runtime_ai_dev_tools.getDeviceSize',
  );

  // ext.runtime_ai_dev_tools.setDeviceSize
  developer.registerExtension('ext.runtime_ai_dev_tools.setDeviceSize', (
    String method,
    Map<String, String> parameters,
  ) async {
    print('📥 [RuntimeAiDevTools] setDeviceSize extension called');
    print('   Method: $method');
    print('   Parameters: $parameters');

    try {
      // Check for preset first
      final presetName = parameters['preset'];
      double? width;
      double? height;
      double? devicePixelRatio;

      if (presetName != null) {
        final preset = DevicePresets.byName(presetName);
        if (preset == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Unknown preset: $presetName. Available presets: ${DevicePresets.names.join(", ")}',
          );
        }
        width = preset.width;
        height = preset.height;
        devicePixelRatio = preset.devicePixelRatio;
      } else {
        // Use explicit width/height
        final widthStr = parameters['width'];
        final heightStr = parameters['height'];

        if (widthStr == null || heightStr == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required parameters: either preset, or width and height',
          );
        }

        width = double.tryParse(widthStr);
        height = double.tryParse(heightStr);

        if (width == null || height == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Invalid width or height value',
          );
        }

        final dprStr = parameters['devicePixelRatio'];
        if (dprStr != null) {
          devicePixelRatio = double.tryParse(dprStr);
        }
      }

      final showFrameStr = parameters['showFrame'];
      final showFrame = showFrameStr != 'false';

      deviceSizeState.setDeviceSize(
        width: width,
        height: height,
        devicePixelRatio: devicePixelRatio,
        showFrame: showFrame,
      );

      print(
        '✅ [RuntimeAiDevTools] Device size set to ${width}x$height @ ${devicePixelRatio}x, frame: $showFrame',
      );

      return developer.ServiceExtensionResponse.result(
        json.encode({
          'status': 'success',
          'width': width,
          'height': height,
          'devicePixelRatio': devicePixelRatio,
          'showFrame': showFrame,
        }),
      );
    } catch (e, stackTrace) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        'Failed to set device size: $e\n$stackTrace',
      );
    }
  });

  // ext.runtime_ai_dev_tools.resetDeviceSize
  developer.registerExtension('ext.runtime_ai_dev_tools.resetDeviceSize', (
    String method,
    Map<String, String> parameters,
  ) async {
    print('📥 [RuntimeAiDevTools] resetDeviceSize extension called');

    try {
      deviceSizeState.resetDeviceSize();
      print('✅ [RuntimeAiDevTools] Device size reset to native');

      return developer.ServiceExtensionResponse.result(
        json.encode({
          'status': 'success',
          'message': 'Device size reset to native',
        }),
      );
    } catch (e, stackTrace) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        'Failed to reset device size: $e\n$stackTrace',
      );
    }
  });

  // ext.runtime_ai_dev_tools.getDeviceSize
  developer.registerExtension('ext.runtime_ai_dev_tools.getDeviceSize', (
    String method,
    Map<String, String> parameters,
  ) async {
    print('📥 [RuntimeAiDevTools] getDeviceSize extension called');

    try {
      final settings = deviceSizeState.settings;

      if (settings == null) {
        return developer.ServiceExtensionResponse.result(
          json.encode({
            'status': 'success',
            'override': false,
            'message': 'Using native device size',
          }),
        );
      }

      return developer.ServiceExtensionResponse.result(
        json.encode({
          'status': 'success',
          'override': true,
          ...settings.toJson(),
        }),
      );
    } catch (e, stackTrace) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        'Failed to get device size: $e\n$stackTrace',
      );
    }
  });
}
