/// Exception thrown when a git operation fails
class GitException implements Exception {
  final String message;
  final int? exitCode;
  final String? stderr;
  final List<String> command;

  GitException(
    this.message, {
    this.exitCode,
    this.stderr,
    this.command = const [],
  });

  @override
  String toString() {
    final buffer = StringBuffer('GitException: $message');
    if (exitCode != null) {
      buffer.write(' (exit code: $exitCode)');
    }
    if (stderr != null && stderr!.isNotEmpty) {
      buffer.write('\n$stderr');
    }
    if (command.isNotEmpty) {
      buffer.write('\nCommand: git ${command.join(' ')}');
    }
    return buffer.toString();
  }
}
