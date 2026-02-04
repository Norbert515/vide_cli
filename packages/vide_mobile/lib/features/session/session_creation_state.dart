import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_creation_state.freezed.dart';
part 'session_creation_state.g.dart';

/// Permission mode for tool execution.
enum PermissionMode {
  defaultMode('default', 'Ask for each tool'),
  autoApprove('auto-approve', 'Auto-approve all');

  const PermissionMode(this.value, this.displayName);
  final String value;
  final String displayName;
}

/// State for session creation form.
@freezed
class SessionCreationState with _$SessionCreationState {
  const factory SessionCreationState({
    @Default('') String initialMessage,
    @Default('') String workingDirectory,
    @Default('vide') String team,
    @Default(PermissionMode.defaultMode) PermissionMode permissionMode,
    @Default(false) bool isCreating,
    String? error,
  }) = _SessionCreationState;
}

/// Provider for session creation state.
@riverpod
class SessionCreationNotifier extends _$SessionCreationNotifier {
  @override
  SessionCreationState build() {
    return const SessionCreationState();
  }

  void setInitialMessage(String message) {
    state = state.copyWith(initialMessage: message);
  }

  void setWorkingDirectory(String directory) {
    state = state.copyWith(workingDirectory: directory);
  }

  void setTeam(String team) {
    state = state.copyWith(team: team);
  }

  void setPermissionMode(PermissionMode mode) {
    state = state.copyWith(permissionMode: mode);
  }

  void setIsCreating(bool isCreating) {
    state = state.copyWith(isCreating: isCreating);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  bool validate() {
    if (state.initialMessage.trim().isEmpty) {
      setError('Please enter an initial message');
      return false;
    }
    if (state.workingDirectory.isEmpty) {
      setError('Please select a working directory');
      return false;
    }
    setError(null);
    return true;
  }

  void reset() {
    state = const SessionCreationState();
  }
}
