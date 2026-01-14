import 'dart:convert';
import 'dart:io';

import '../control/control_protocol.dart';
import '../control/control_types.dart';
import '../errors/claude_errors.dart';
import '../models/config.dart';

/// Manages the lifecycle of a Claude CLI process.
///
/// This class handles:
/// - Starting the Claude CLI process with control protocol
/// - Tracking the active process state
/// - Cleaning up resources
class ProcessLifecycleManager {
  /// The currently active Claude CLI process
  Process? _activeProcess;

  /// The control protocol handler for the active process
  ControlProtocol? _controlProtocol;

  /// Get the active process, if any
  Process? get activeProcess => _activeProcess;

  /// The control protocol for the active process
  ControlProtocol? get controlProtocol => _controlProtocol;

  /// Whether a process is currently running
  bool get isRunning => _activeProcess != null;

  /// Start the Claude CLI process with control protocol.
  ///
  /// Returns the [ControlProtocol] handler for the started process.
  ///
  /// Throws [StateError] if a process is already running.
  /// Throws [ProcessStartException] if the process fails to start.
  Future<ControlProtocol> startProcess({
    required ClaudeConfig config,
    required List<String> args,
    Map<HookEvent, List<HookMatcher>>? hooks,
    CanUseToolCallback? canUseTool,
  }) async {
    if (_activeProcess != null) {
      throw StateError(
        'Cannot start a new process while one is already running. '
        'Call close() first.',
      );
    }

    // Start the process
    // On Windows, use 'claude.cmd' since npm installs it as a .cmd wrapper
    final executable = Platform.isWindows ? 'claude.cmd' : 'claude';
    Process process;
    try {
      process = await Process.start(
        executable,
        args,
        environment: <String, String>{'MCP_TOOL_TIMEOUT': '30000000'},
        runInShell: true,
        includeParentEnvironment: true,
        workingDirectory: config.workingDirectory,
      );
    } catch (e, stackTrace) {
      throw ProcessStartException(
        'Failed to start Claude CLI process',
        cause: e,
        stackTrace: stackTrace,
      );
    }
    _activeProcess = process;

    // Create control protocol handler
    _controlProtocol = ControlProtocol(process);

    // Consume stderr to prevent blocking (errors are surfaced via control protocol)
    process.stderr.transform(utf8.decoder).drain<void>();

    // Initialize with hooks
    try {
      await _controlProtocol!.initialize(hooks: hooks, canUseTool: canUseTool);
    } catch (e, stackTrace) {
      // Clean up on initialization failure
      _activeProcess?.kill();
      _activeProcess = null;
      _controlProtocol = null;

      throw ControlProtocolException(
        'Failed to initialize control protocol',
        cause: e,
        stackTrace: stackTrace,
      );
    }

    return _controlProtocol!;
  }

  /// Close and clean up all resources.
  ///
  /// Kills the active process if running and cleans up the control protocol.
  Future<void> close() async {
    // Close control protocol if active
    if (_controlProtocol != null) {
      await _controlProtocol!.close();
      _controlProtocol = null;
    }

    // Kill active process if any
    if (_activeProcess != null) {
      _activeProcess!.kill();
      _activeProcess = null;
    }
  }
}
