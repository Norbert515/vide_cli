import 'dart:io';

import 'package:path/path.dart' as p;

import 'daemon_info.dart';

/// Abstract service installer for platform-specific daemon registration.
abstract class ServiceInstaller {
  /// Create the appropriate installer for the current platform.
  factory ServiceInstaller() {
    if (Platform.isMacOS) return LaunchdInstaller();
    if (Platform.isLinux) return SystemdInstaller();
    throw UnsupportedError(
      'Service installation is not supported on ${Platform.operatingSystem}',
    );
  }

  /// Install the daemon as a system service.
  Future<void> install({required int port, required String host});

  /// Uninstall the daemon system service.
  Future<void> uninstall();

  /// Check if the service is currently installed.
  bool isInstalled();

  /// Resolve the vide binary path.
  ///
  /// Prefers the installed binary at ~/.vide/bin/vide,
  /// falls back to the current executable.
  static String resolveVideBinary() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      final installedBinary = p.join(home, '.vide', 'bin', 'vide');
      if (File(installedBinary).existsSync()) return installedBinary;
    }
    return Platform.resolvedExecutable;
  }

  /// Escape a string for safe use in XML content.
  static String _xmlEscape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Validate that a host string is safe for use in templates.
  ///
  /// Accepts valid IPv4 addresses, IPv6 addresses, and hostnames.
  /// Rejects values containing newlines, XML special characters,
  /// or other injection vectors.
  static void validateHost(String host) {
    if (host.isEmpty) {
      throw ArgumentError('Host cannot be empty');
    }
    // Only allow characters valid in hostnames/IPs: alphanumeric, dots, colons, hyphens, brackets
    if (!RegExp(r'^[a-zA-Z0-9.:@\[\]-]+$').hasMatch(host)) {
      throw ArgumentError(
        'Invalid host "$host": contains disallowed characters',
      );
    }
  }

  /// Validate that a binary path is safe for use in templates.
  static void validatePath(String path) {
    if (path.contains('\n') || path.contains('\r')) {
      throw ArgumentError('Path cannot contain newlines');
    }
  }
}

/// macOS launchd service installer.
///
/// Creates a LaunchAgent plist at ~/Library/LaunchAgents/com.vide.daemon.plist
/// that starts the daemon on login.
class LaunchdInstaller implements ServiceInstaller {
  static const _label = 'com.vide.daemon';

  String get _plistPath {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return p.join(home, 'Library', 'LaunchAgents', '$_label.plist');
  }

  @override
  Future<void> install({required int port, required String host}) async {
    ServiceInstaller.validateHost(host);

    if (isInstalled()) {
      // Unload first to apply new config
      await _launchctl(['unload', _plistPath]);
    }

    final binaryPath = ServiceInstaller.resolveVideBinary();
    final logPath = DaemonInfo.logFilePath();

    ServiceInstaller.validatePath(binaryPath);
    ServiceInstaller.validatePath(logPath);

    // Ensure log directory exists
    await Directory(DaemonInfo.logDir()).create(recursive: true);

    final plist = generatePlist(
      binaryPath: binaryPath,
      port: port,
      host: host,
      logPath: logPath,
    );

    final plistFile = File(_plistPath);
    await plistFile.parent.create(recursive: true);
    await plistFile.writeAsString(plist);

    await _launchctl(['load', _plistPath]);

    print('Installed daemon service: $_label');
    print('  Plist: $_plistPath');
    print('  Binary: $binaryPath');
    print('  URL: http://$host:$port');
    print('  Logs: $logPath');
    print('');
    print('The daemon will start automatically on login.');
    print('To start it now: launchctl start $_label');
  }

  @override
  Future<void> uninstall() async {
    if (!isInstalled()) {
      print('Service is not installed.');
      return;
    }

    await _launchctl(['unload', _plistPath]);
    File(_plistPath).deleteSync();

    print('Uninstalled daemon service: $_label');
    print('Removed: $_plistPath');
  }

  @override
  bool isInstalled() => File(_plistPath).existsSync();

  /// Generate the plist XML content.
  ///
  /// All interpolated values are XML-escaped to prevent injection.
  /// Visible for testing.
  static String generatePlist({
    required String binaryPath,
    required int port,
    required String host,
    required String logPath,
  }) {
    final esc = ServiceInstaller._xmlEscape;
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$_label</string>
  <key>ProgramArguments</key>
  <array>
    <string>${esc(binaryPath)}</string>
    <string>daemon</string>
    <string>start</string>
    <string>--port</string>
    <string>$port</string>
    <string>--host</string>
    <string>${esc(host)}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${esc(logPath)}</string>
  <key>StandardErrorPath</key>
  <string>${esc(logPath)}</string>
</dict>
</plist>
''';
  }

  Future<void> _launchctl(List<String> args) async {
    final result = await Process.run('launchctl', args);
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      if (stderr.isNotEmpty) {
        print('launchctl warning: $stderr');
      }
    }
  }
}

/// Linux systemd user service installer (stub).
///
/// Generates a systemd user service file and prints manual instructions.
class SystemdInstaller implements ServiceInstaller {
  static const _serviceName = 'vide-daemon';

  String get _servicePath {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return p.join(
      home,
      '.config',
      'systemd',
      'user',
      '$_serviceName.service',
    );
  }

  @override
  Future<void> install({required int port, required String host}) async {
    ServiceInstaller.validateHost(host);

    final binaryPath = ServiceInstaller.resolveVideBinary();
    ServiceInstaller.validatePath(binaryPath);

    final serviceContent = generateServiceFile(
      binaryPath: binaryPath,
      port: port,
      host: host,
    );

    final serviceFile = File(_servicePath);
    await serviceFile.parent.create(recursive: true);
    await serviceFile.writeAsString(serviceContent);

    print('Generated systemd user service: $_servicePath');
    print('');
    print('To enable and start the service, run:');
    print('  systemctl --user daemon-reload');
    print('  systemctl --user enable $_serviceName');
    print('  systemctl --user start $_serviceName');
    print('');
    print('To check status:');
    print('  systemctl --user status $_serviceName');
    print('');
    print('To view logs:');
    print('  journalctl --user -u $_serviceName -f');
  }

  @override
  Future<void> uninstall() async {
    if (!isInstalled()) {
      print('Service is not installed.');
      return;
    }

    print('To stop and disable the service, run:');
    print('  systemctl --user stop $_serviceName');
    print('  systemctl --user disable $_serviceName');
    print('');

    File(_servicePath).deleteSync();
    print('Removed: $_servicePath');
    print('');
    print('Run: systemctl --user daemon-reload');
  }

  @override
  bool isInstalled() => File(_servicePath).existsSync();

  /// Generate the systemd service file content.
  ///
  /// Validates inputs to prevent injection of extra directives.
  /// Visible for testing.
  static String generateServiceFile({
    required String binaryPath,
    required int port,
    required String host,
  }) {
    ServiceInstaller.validateHost(host);
    ServiceInstaller.validatePath(binaryPath);
    return '''[Unit]
Description=Vide Daemon - Persistent session manager
After=network.target

[Service]
Type=simple
ExecStart=$binaryPath daemon start --port $port --host $host
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
''';
  }
}
