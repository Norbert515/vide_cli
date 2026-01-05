import 'dart:async';
import 'dart:io';
import 'package:flutter_runtime_mcp/flutter_runtime_mcp.dart';

/// Main TUI application for testing Flutter Runtime MCP
class FlutterRuntimeTUI {
  final FlutterRuntimeServer _server;
  final _outputController = StreamController<String>.broadcast();
  final _localInstances =
      <String, FlutterInstance>{}; // Track instances started from TUI
  bool _running = true;
  String _currentView = 'main'; // main, details, start, output
  String? _selectedInstanceId;
  final List<String> _startFormFields = [
    '',
    '',
    '',
  ]; // command, workingDir, deviceId

  FlutterRuntimeTUI(this._server);

  Stream<String> get output => _outputController.stream;

  Future<void> run() async {
    _clearScreen();
    _showHeader();

    // Setup stdin for raw mode
    stdin.echoMode = false;
    stdin.lineMode = false;

    _showMainMenu();

    // Listen to keyboard input
    stdin.listen((codes) {
      final key = String.fromCharCodes(codes);
      _handleInput(key);
    });

    // Keep app running
    while (_running) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Cleanup
    _outputController.close();
  }

  void _handleInput(String key) {
    switch (_currentView) {
      case 'main':
        _handleMainMenuInput(key);
        break;
      case 'details':
        _handleDetailsInput(key);
        break;
      case 'start':
        _handleStartFormInput(key);
        break;
      case 'output':
        _handleOutputViewInput(key);
        break;
    }
  }

  void _handleMainMenuInput(String key) {
    switch (key.toLowerCase()) {
      case 'l':
        _showInstanceList();
        break;
      case 's':
        _showStartForm();
        break;
      case 'r':
        _showMainMenu();
        break;
      case 'q':
        _quit();
        break;
      default:
        // Try to parse as instance number
        final num = int.tryParse(key);
        if (num != null) {
          final instances = [
            ..._server.getAllInstances(),
            ..._localInstances.values,
          ];
          if (num > 0 && num <= instances.length) {
            _selectedInstanceId = instances[num - 1].id;
            _showInstanceDetails();
          }
        }
    }
  }

  void _handleDetailsInput(String key) {
    switch (key.toLowerCase()) {
      case 'r':
        _hotReload();
        break;
      case 'R':
        _hotRestart();
        break;
      case 'o':
        _showOutputView();
        break;
      case 's':
        _takeScreenshot();
        break;
      case 'k':
        _stopInstance();
        break;
      case 'b':
        _currentView = 'main';
        _showMainMenu();
        break;
      case 'q':
        _quit();
        break;
    }
  }

  void _handleStartFormInput(String key) {
    if (key == '\n' || key == '\r') {
      _startFlutterInstance();
    } else if (key.toLowerCase() == 'b') {
      _currentView = 'main';
      _showMainMenu();
    } else if (key.toLowerCase() == 'q') {
      _quit();
    }
  }

  void _handleOutputViewInput(String key) {
    if (key.toLowerCase() == 'b') {
      _currentView = 'details';
      _showInstanceDetails();
    } else if (key.toLowerCase() == 'q') {
      _quit();
    }
  }

  void _clearScreen() {
    print('\x1B[2J\x1B[0;0H');
  }

  void _showHeader() {
    print('╔════════════════════════════════════════════════════════════════╗');
    print('║        Flutter Runtime MCP - TUI Test Application             ║');
    print('╚════════════════════════════════════════════════════════════════╝');
    print('');
  }

  void _showMainMenu() {
    _clearScreen();
    _showHeader();

    // Combine server instances and local instances
    final instances = [..._server.getAllInstances(), ..._localInstances.values];

    print(
      '┌─ Running Instances (${instances.length}) ─────────────────────────────────┐',
    );
    print('');

    if (instances.isEmpty) {
      print('  No running instances');
    } else {
      for (var i = 0; i < instances.length; i++) {
        final instance = instances[i];
        final status = instance.isRunning ? '🟢 Running' : '🔴 Stopped';
        final device = instance.deviceId ?? 'unknown';
        final duration = DateTime.now().difference(instance.startedAt);

        print('  ${i + 1}. $status - $device (${_formatDuration(duration)})');
        print('     ${instance.id}');
        print('     ${_truncate(instance.workingDirectory, 60)}');
        print('');
      }
    }

    print('└────────────────────────────────────────────────────────────────┘');
    print('');
    print('Commands:');
    print('  [l] List/refresh instances');
    print('  [s] Start new instance');
    print('  [1-9] Select instance by number');
    print('  [r] Refresh view');
    print('  [q] Quit');
    print('');
    print('> ');
  }

  void _showInstanceList() {
    _showMainMenu();
  }

  void _showInstanceDetails() {
    final instance =
        _server.getInstance(_selectedInstanceId!) ??
        _localInstances[_selectedInstanceId];
    if (instance == null) {
      _showError('Instance not found');
      _currentView = 'main';
      _showMainMenu();
      return;
    }

    _clearScreen();
    _showHeader();

    print('┌─ Instance Details ─────────────────────────────────────────────┐');
    print('');
    print('  ID: ${instance.id}');
    print('  Status: ${instance.isRunning ? '🟢 Running' : '🔴 Stopped'}');
    print('  Started: ${instance.startedAt}');
    print(
      '  Uptime: ${_formatDuration(DateTime.now().difference(instance.startedAt))}',
    );
    print('');
    print('  Working Directory:');
    print('    ${instance.workingDirectory}');
    print('');
    print('  Command:');
    print('    ${instance.command.join(' ')}');
    print('');
    print('  Device: ${instance.deviceId ?? 'parsing...'}');
    print('  VM Service: ${instance.vmServiceUri ?? 'not available'}');
    print('');
    print('  Output Lines: ${instance.bufferedOutput.length}');
    print('  Error Lines: ${instance.bufferedErrors.length}');
    print('');
    print('└────────────────────────────────────────────────────────────────┘');
    print('');
    print('Commands:');
    print('  [r] Hot Reload');
    print('  [R] Hot Restart');
    print('  [o] View Output');
    print('  [s] Take Screenshot');
    print('  [k] Stop Instance');
    print('  [b] Back to main menu');
    print('  [q] Quit');
    print('');
    print('> ');
  }

  void _showStartForm() {
    _currentView = 'start';
    _clearScreen();
    _showHeader();

    print('┌─ Start New Flutter Instance ──────────────────────────────────┐');
    print('');
    print('  This is a simplified start form.');
    print('  For full control, use the command line or edit the values below.');
    print('');
    print('  Example commands:');
    print('    flutter run -d chrome');
    print('    flutter run -d macos');
    print('    flutter run -d "iPhone 15 Pro"');
    print('');
    print('  Enter command: ');
    print('  > ');

    // Read command from stdin synchronously
    stdin.lineMode = true;
    stdin.echoMode = true;
    final command = stdin.readLineSync();
    stdin.lineMode = false;
    stdin.echoMode = false;

    if (command != null && command.isNotEmpty) {
      _startFormFields[0] = command;

      print('');
      print('  Enter working directory (or press Enter for current): ');
      print('  > ');

      stdin.lineMode = true;
      stdin.echoMode = true;
      final workingDir = stdin.readLineSync();
      stdin.lineMode = false;
      stdin.echoMode = false;

      _startFormFields[1] = workingDir ?? Directory.current.path;

      _startFlutterInstance();
    } else {
      _currentView = 'main';
      _showMainMenu();
    }
  }

  Future<void> _startFlutterInstance() async {
    final command = _startFormFields[0];
    final workingDir = _startFormFields[1].isEmpty
        ? Directory.current.path
        : _startFormFields[1];

    _clearScreen();
    _showHeader();
    print('Starting Flutter instance...');
    print('Command: $command');
    print('Working Directory: $workingDir');
    print('');
    print('Please wait...');

    try {
      final commandParts = _parseCommand(command);

      // Validate command
      if (commandParts.isEmpty ||
          (commandParts.first != 'flutter' && commandParts.first != 'fvm')) {
        print('');
        print('✗ Error: Command must start with "flutter" or "fvm"');
        print('');
        print('Press any key to continue...');
        await stdin.first;
        _currentView = 'main';
        _showMainMenu();
        return;
      }

      final instanceId = 'tui-${DateTime.now().millisecondsSinceEpoch}';

      // Start the process directly
      final process = await Process.start(
        commandParts.first,
        commandParts.sublist(1),
        workingDirectory: workingDir,
        mode: ProcessStartMode.normal,
      );

      // Create instance wrapper
      final instance = FlutterInstance(
        id: instanceId,
        process: process,
        workingDirectory: workingDir,
        command: commandParts,
        startedAt: DateTime.now(),
      );

      // Track locally
      _localInstances[instanceId] = instance;

      // Set up auto-cleanup when process exits
      instance.process.exitCode.then((_) {
        _localInstances.remove(instanceId);
      });

      // Wait for startup
      print('Waiting for Flutter to start...');
      final result = await instance.waitForStartup(
        timeout: const Duration(seconds: 90),
      );

      if (result.isSuccess) {
        _selectedInstanceId = instance.id;
        print('');
        print('✓ Flutter instance started successfully!');
        print('');
        await Future.delayed(const Duration(seconds: 2));
        _currentView = 'details';
        _showInstanceDetails();
      } else {
        _localInstances.remove(instanceId);
        print('');
        print('✗ Failed to start Flutter instance');
        print('Status: ${result.status}');
        if (result.message != null) {
          print('Message: ${result.message}');
        }
        print('');
        print('Press any key to continue...');
        await stdin.first;
        _currentView = 'main';
        _showMainMenu();
      }
    } catch (e) {
      print('');
      print('✗ Error: $e');
      print('');
      print('Press any key to continue...');
      await stdin.first;
      _currentView = 'main';
      _showMainMenu();
    }

    // Clear form
    _startFormFields[0] = '';
    _startFormFields[1] = '';
  }

  void _showOutputView() {
    final instance =
        _server.getInstance(_selectedInstanceId!) ??
        _localInstances[_selectedInstanceId];
    if (instance == null) {
      _showError('Instance not found');
      return;
    }

    _currentView = 'output';
    _clearScreen();
    _showHeader();

    print('┌─ Output View (Last 20 lines) ──────────────────────────────────┐');
    print('');

    final outputLines = instance.bufferedOutput.length > 20
        ? instance.bufferedOutput.sublist(instance.bufferedOutput.length - 20)
        : instance.bufferedOutput;

    for (final line in outputLines) {
      print('  $line');
    }

    print('');
    print('└────────────────────────────────────────────────────────────────┘');
    print('');

    if (instance.bufferedErrors.isNotEmpty) {
      print(
        '┌─ Errors (Last 10 lines) ───────────────────────────────────────┐',
      );
      print('');

      final errorLines = instance.bufferedErrors.length > 10
          ? instance.bufferedErrors.sublist(instance.bufferedErrors.length - 10)
          : instance.bufferedErrors;

      for (final line in errorLines) {
        print('  [ERROR] $line');
      }

      print('');
      print(
        '└────────────────────────────────────────────────────────────────┘',
      );
    }

    print('');
    print('Commands:');
    print('  [b] Back to instance details');
    print('  [q] Quit');
    print('');
    print('> ');
  }

  Future<void> _hotReload() async {
    final instance =
        _server.getInstance(_selectedInstanceId!) ??
        _localInstances[_selectedInstanceId];
    if (instance == null) {
      _showError('Instance not found');
      return;
    }

    _showStatus('Triggering hot reload...');

    try {
      await instance.hotReload();
      _showSuccess('Hot reload triggered successfully');
      await Future.delayed(const Duration(seconds: 1));
      _showInstanceDetails();
    } catch (e) {
      _showError('Hot reload failed: $e');
      await Future.delayed(const Duration(seconds: 2));
      _showInstanceDetails();
    }
  }

  Future<void> _hotRestart() async {
    final instance =
        _server.getInstance(_selectedInstanceId!) ??
        _localInstances[_selectedInstanceId];
    if (instance == null) {
      _showError('Instance not found');
      return;
    }

    _showStatus('Triggering hot restart...');

    try {
      await instance.hotRestart();
      _showSuccess('Hot restart triggered successfully');
      await Future.delayed(const Duration(seconds: 1));
      _showInstanceDetails();
    } catch (e) {
      _showError('Hot restart failed: $e');
      await Future.delayed(const Duration(seconds: 2));
      _showInstanceDetails();
    }
  }

  Future<void> _takeScreenshot() async {
    final instance =
        _server.getInstance(_selectedInstanceId!) ??
        _localInstances[_selectedInstanceId];
    if (instance == null) {
      _showError('Instance not found');
      return;
    }

    _showStatus('Taking screenshot...');

    try {
      final screenshot = await instance.screenshot();

      if (screenshot != null) {
        final filename =
            'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filename);
        await file.writeAsBytes(screenshot);

        _showSuccess(
          'Screenshot saved to: $filename (${screenshot.length} bytes)',
        );
      } else {
        _showError(
          'Screenshot returned null - VM Service may not be available',
        );
      }

      await Future.delayed(const Duration(seconds: 2));
      _showInstanceDetails();
    } catch (e) {
      _showError('Screenshot failed: $e');
      await Future.delayed(const Duration(seconds: 2));
      _showInstanceDetails();
    }
  }

  Future<void> _stopInstance() async {
    final instance =
        _server.getInstance(_selectedInstanceId!) ??
        _localInstances[_selectedInstanceId];
    if (instance == null) {
      _showError('Instance not found');
      return;
    }

    _showStatus('Stopping instance...');

    try {
      await instance.stop();
      _showSuccess('Instance stopped successfully');
      await Future.delayed(const Duration(seconds: 1));
      _selectedInstanceId = null;
      _currentView = 'main';
      _showMainMenu();
    } catch (e) {
      _showError('Stop failed: $e');
      await Future.delayed(const Duration(seconds: 2));
      _showInstanceDetails();
    }
  }

  void _showStatus(String message) {
    print('');
    print('⏳ $message');
    print('');
  }

  void _showSuccess(String message) {
    print('');
    print('✓ $message');
    print('');
  }

  void _showError(String message) {
    print('');
    print('✗ $message');
    print('');
  }

  void _quit() {
    _clearScreen();
    _showHeader();
    print('Shutting down...');
    print('');

    final instances = [..._server.getAllInstances(), ..._localInstances.values];
    if (instances.isNotEmpty) {
      print('Stopping ${instances.length} running instance(s)...');
      for (final instance in instances) {
        try {
          instance.stop();
        } catch (e) {
          print('Warning: Failed to stop ${instance.id}: $e');
        }
      }
    }

    print('');
    print('Goodbye!');
    _running = false;
    exit(0);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  List<String> _parseCommand(String command) {
    final parts = <String>[];
    var current = StringBuffer();
    var inQuote = false;
    var quoteChar = '';

    for (var i = 0; i < command.length; i++) {
      final char = command[i];

      if ((char == '"' || char == "'") && !inQuote) {
        inQuote = true;
        quoteChar = char;
      } else if (char == quoteChar && inQuote) {
        inQuote = false;
        quoteChar = '';
      } else if (char == ' ' && !inQuote) {
        if (current.isNotEmpty) {
          parts.add(current.toString());
          current = StringBuffer();
        }
      } else {
        current.write(char);
      }
    }

    if (current.isNotEmpty) {
      parts.add(current.toString());
    }

    return parts;
  }
}
