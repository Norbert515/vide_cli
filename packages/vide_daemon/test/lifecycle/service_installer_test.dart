import 'package:test/test.dart';
import 'package:vide_daemon/vide_daemon.dart';

void main() {
  group('LaunchdInstaller.generatePlist', () {
    test('generates valid plist XML with correct values', () {
      final plist = LaunchdInstaller.generatePlist(
        binaryPath: '/Users/test/.vide/bin/vide',
        port: 8093,
        host: '100.69.74.9',
        logPath: '/Users/test/.vide/daemon/logs/daemon.log',
      );

      expect(plist, contains('<?xml version="1.0"'));
      expect(plist, contains('<string>com.vide.daemon</string>'));
      expect(plist, contains('<string>/Users/test/.vide/bin/vide</string>'));
      expect(plist, contains('<string>daemon</string>'));
      expect(plist, contains('<string>start</string>'));
      expect(plist, contains('<string>--port</string>'));
      expect(plist, contains('<string>8093</string>'));
      expect(plist, contains('<string>--host</string>'));
      expect(plist, contains('<string>100.69.74.9</string>'));
      expect(plist, contains('<key>RunAtLoad</key>'));
      expect(plist, contains('<true/>'));
      expect(plist, contains('<key>KeepAlive</key>'));
      expect(
        plist,
        contains('<string>/Users/test/.vide/daemon/logs/daemon.log</string>'),
      );
    });

    test('generates plist with localhost defaults', () {
      final plist = LaunchdInstaller.generatePlist(
        binaryPath: '/usr/local/bin/vide',
        port: 8080,
        host: '127.0.0.1',
        logPath: '/tmp/daemon.log',
      );

      expect(plist, contains('<string>8080</string>'));
      expect(plist, contains('<string>127.0.0.1</string>'));
      expect(plist, contains('<string>/usr/local/bin/vide</string>'));
    });
  });

  group('SystemdInstaller.generateServiceFile', () {
    test('generates valid systemd unit file', () {
      final service = SystemdInstaller.generateServiceFile(
        binaryPath: '/usr/local/bin/vide',
        port: 9000,
        host: '10.0.0.1',
      );

      expect(service, contains('[Unit]'));
      expect(service, contains('Description=Vide Daemon'));
      expect(service, contains('[Service]'));
      expect(service, contains('Type=simple'));
      expect(
        service,
        contains(
          'ExecStart=/usr/local/bin/vide daemon start --port 9000 --host 10.0.0.1',
        ),
      );
      expect(service, contains('Restart=on-failure'));
      expect(service, contains('[Install]'));
      expect(service, contains('WantedBy=default.target'));
    });
  });
}
