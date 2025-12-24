import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A fake Process implementation for testing ClaudeClientImpl
/// without actually spawning CLI processes.
class FakeProcess implements Process {
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final Completer<int> _exitCodeCompleter = Completer<int>();
  final _FakeIOSink _stdinSink = _FakeIOSink();

  bool _killed = false;
  ProcessSignal? _killSignal;

  /// Lines written to stdin
  List<String> get stdinLines => _stdinSink.lines;

  /// Whether kill was called
  bool get wasKilled => _killed;

  /// The signal used to kill the process
  ProcessSignal? get killSignal => _killSignal;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  IOSink get stdin => _stdinSink;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  int get pid => 12345; // Fake PID

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _killed = true;
    _killSignal = signal;
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(-1);
    }
    return true;
  }

  // ===== Test control methods =====

  /// Emit a JSON line to stdout (simulating Claude CLI output)
  void emitStdout(String jsonLine) {
    _stdoutController.add(utf8.encode('$jsonLine\n'));
  }

  /// Emit multiple JSON lines to stdout
  void emitStdoutLines(List<String> jsonLines) {
    for (final line in jsonLines) {
      emitStdout(line);
    }
  }

  /// Emit raw bytes to stdout (for testing partial chunks)
  void emitStdoutRaw(List<int> bytes) {
    _stdoutController.add(bytes);
  }

  /// Emit a line to stderr (simulating CLI errors)
  void emitStderr(String line) {
    _stderrController.add(utf8.encode('$line\n'));
  }

  /// Complete the process with an exit code
  void complete([int exitCode = 0]) {
    _stdoutController.close();
    _stderrController.close();
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(exitCode);
    }
  }

  /// Complete with error (simulates process failure)
  void completeWithError(int exitCode, String errorMessage) {
    emitStderr(errorMessage);
    complete(exitCode);
  }

  /// Dispose controllers (call in test tearDown)
  Future<void> dispose() async {
    if (!_stdoutController.isClosed) {
      await _stdoutController.close();
    }
    if (!_stderrController.isClosed) {
      await _stderrController.close();
    }
  }
}

/// Fake IOSink that captures written data
class _FakeIOSink implements IOSink {
  final List<String> lines = [];
  final StringBuffer _buffer = StringBuffer();
  bool _closed = false;

  /// Whether the sink has been closed
  bool get isClosed => _closed;

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {
    _buffer.write(utf8.decode(data));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future close() async {
    _closed = true;
    final content = _buffer.toString();
    if (content.isNotEmpty) {
      lines.addAll(content.split('\n').where((l) => l.isNotEmpty));
    }
  }

  @override
  Future get done => Future.value();

  @override
  Future flush() async {}

  @override
  void write(Object? object) {
    _buffer.write(object);
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    _buffer.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _buffer.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    _buffer.writeln(object);
    // Extract lines when newline is written
    final content = _buffer.toString();
    final splitLines = content.split('\n');
    if (splitLines.length > 1) {
      lines.addAll(
          splitLines.take(splitLines.length - 1).where((l) => l.isNotEmpty));
      _buffer.clear();
      _buffer.write(splitLines.last);
    }
  }
}

/// A ProcessRunner that returns FakeProcess instances for testing
class FakeProcessRunner {
  final List<FakeProcess> _processes = [];
  final List<ProcessStartCall> capturedCalls = [];

  /// Queue a FakeProcess to be returned by the next start() call
  FakeProcess queueProcess() {
    final process = FakeProcess();
    _processes.add(process);
    return process;
  }

  /// Start a process (returns queued FakeProcess)
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async {
    capturedCalls.add(ProcessStartCall(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
    ));

    if (_processes.isEmpty) {
      throw StateError('No FakeProcess queued. Call queueProcess() first.');
    }

    return _processes.removeAt(0);
  }

  /// Get the last captured call
  ProcessStartCall? get lastCall =>
      capturedCalls.isNotEmpty ? capturedCalls.last : null;

  /// Clear all captured calls
  void clearCalls() => capturedCalls.clear();
}

/// Captured process start call for assertions
class ProcessStartCall {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;
  final bool includeParentEnvironment;
  final bool runInShell;

  ProcessStartCall({
    required this.executable,
    required this.arguments,
    this.workingDirectory,
    this.environment,
    this.includeParentEnvironment = true,
    this.runInShell = false,
  });
}
