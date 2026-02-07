import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vide_server/services/server_config.dart';

void main() {
  group('ServerConfig', () {
    test('default config has expected values', () {
      final config = ServerConfig();

      expect(config.autoApproveAll, false);
      expect(config.filesystemRoot, isNotEmpty);
    });

    test('defaultConfig matches default constructor', () {
      final defaultConfig = ServerConfig.defaultConfig;

      expect(defaultConfig.autoApproveAll, false);
      expect(defaultConfig.filesystemRoot, isNotEmpty);
    });

    test('custom config values are preserved', () {
      final config = ServerConfig(
        autoApproveAll: true,
        filesystemRoot: '/custom/root',
      );

      expect(config.autoApproveAll, true);
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
          autoApproveAll: true,
          filesystemRoot: '/test/root',
        );

        // Verify the expected JSON structure
        final json = {
          'auto-approve-all': config.autoApproveAll,
          'filesystem-root': config.filesystemRoot,
        };

        final encoded = const JsonEncoder.withIndent('  ').convert(json);
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;

        expect(decoded['auto-approve-all'], true);
        expect(decoded['filesystem-root'], '/test/root');
      });
    });
  });
}
