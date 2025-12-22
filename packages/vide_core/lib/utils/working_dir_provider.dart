import 'package:riverpod/riverpod.dart';

/// Riverpod provider for working directory
///
/// This provider MUST be overridden by the UI with the appropriate implementation:
/// - TUI: Returns path.current (current working directory)
/// - REST: Throws descriptive error (working directory must be explicitly provided)
final workingDirProvider = Provider<String>((ref) {
  throw UnimplementedError('workingDirProvider must be overridden by UI');
});
