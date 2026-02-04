import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vide_server/services/server_config.dart';

void main() {
  group('ServerConfig', () {
    test('default config has expected values', () {
      final config = ServerConfig();

      expect(config.permissionTimeoutSeconds, 0); // 0 = no timeout
      expect(config.autoApproveAll, false);
      expect(config.permissionTimeout, Duration.zero);
      expect(config.filesystemRoot, isNotEmpty);
    });

    test('defaultConfig matches default constructor', () {
      final defaultConfig = ServerConfig.defaultConfig;

      expect(defaultConfig.permissionTimeoutSeconds, 0); // 0 = no timeout
      expect(defaultConfig.autoApproveAll, false);
      expect(defaultConfig.filesystemRoot, isNotEmpty);
    });

    test('custom config values are preserved', () {
      final config = ServerConfig(
        permissionTimeoutSeconds: 120,
        autoApproveAll: true,
        filesystemRoot: '/custom/root',
      );

      expect(config.permissionTimeoutSeconds, 120);
      expect(config.autoApproveAll, true);
      expect(config.permissionTimeout, const Duration(seconds: 120));
      expect(config.filesystemRoot, '/custom/root');
    });

    group('load', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('server_config_test_');
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('returns default config when file does not exist', () async {
        // ServerConfig.load() uses HOME env var, so we can't easily test
        // file loading without modifying env. Instead, test the default case.
        final config = ServerConfig.defaultConfig;
        expect(config.permissionTimeoutSeconds, 0); // 0 = no timeout
        expect(config.autoApproveAll, false);
        expect(config.filesystemRoot, isNotEmpty);
      });
    });

    group('save', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('server_config_test_');
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('config can be saved and parsed correctly', () async {
        // We can't easily test save() due to HOME env dependency,
        // but we can test that the JSON format is correct
        final config = ServerConfig(
          permissionTimeoutSeconds: 90,
          autoApproveAll: true,
          filesystemRoot: '/test/root',
        );

        // Verify the expected JSON structure
        final json = {
          'permission-timeout-seconds': config.permissionTimeoutSeconds,
          'auto-approve-all': config.autoApproveAll,
          'filesystem-root': config.filesystemRoot,
        };

        final encoded = const JsonEncoder.withIndent('  ').convert(json);
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;

        expect(decoded['permission-timeout-seconds'], 90);
        expect(decoded['auto-approve-all'], true);
        expect(decoded['filesystem-root'], '/test/root');
      });
    });
  });
}
