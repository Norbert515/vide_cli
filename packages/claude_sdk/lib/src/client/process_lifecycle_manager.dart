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
/// - Aborting/killing the process
/// - Cleaning up resources
class ProcessLifecycleManager {
  /// The currently active Claude CLI process
  Process? _activeProcess;

  /// Whether an abort is currently in progress
  bool _isAborting = false;

  /// The control protocol handler for the active process
  ControlProtocol? _controlProtocol;

  /// Get the active process, if any
  Process? get activeProcess => _activeProcess;

  /// Whether an abort operation is currently in progress
  bool get isAborting => _isAborting;

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
        'Call abort() or close() first.',
      );
    }

    // Start the process
    Process process;
    try {
      process = await Process.start(
        'claude',
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

  /// Start a mock process for testing purposes.
  ///
  /// This starts a simple long-running process that can be aborted.
  /// Used in tests to avoid needing the actual Claude CLI.
  Future<void> startMockProcess() async {
    if (_activeProcess != null) {
      throw StateError(
        'Cannot start a new process while one is already running. '
        'Call abort() or close() first.',
      );
    }

    // Use sleep command which works on Unix systems
    // On Windows, we'd need a different approach
    final process = await Process.start(
      'sleep',
      ['3600'], // Sleep for an hour (will be killed before that)
      runInShell: true,
    );
    _activeProcess = process;
  }

  /// Abort the currently running process.
  ///
  /// First attempts graceful termination with SIGTERM, then force kills
  /// with SIGKILL if the process doesn't exit within [gracefulTimeout].
  ///
  /// Returns the exit code of the terminated process, or null if no
  /// process was running.
  Future<int?> abort({
    Duration gracefulTimeout = const Duration(seconds: 2),
  }) async {
    if (_activeProcess == null) {
      return null;
    }

    _isAborting = true;

    try {
      // Try graceful termination first (SIGTERM)
      _activeProcess!.kill(ProcessSignal.sigterm);

      // Wait for graceful shutdown or force kill
      final exitCode = await _activeProcess!.exitCode.timeout(
        gracefulTimeout,
        onTimeout: () {
          _activeProcess!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );

      return exitCode;
    } finally {
      _activeProcess = null;
      _controlProtocol = null;
      _isAborting = false;
    }
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

    _isAborting = false;
  }
}
