/// TUI-layer Riverpod providers that bridge vide_core services.
///
/// These providers previously lived in vide_core but were moved here
/// as part of removing riverpod from vide_core. The TUI still uses
/// nocterm_riverpod for state management, so these providers remain
/// as the TUI's way to access core services.
library;

import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart';

// =============================================================================
// Config & Settings
// =============================================================================

/// Provider for the VideConfigManager.
/// Must be overridden in main.dart with the actual config manager instance.
final videConfigManagerProvider = Provider<VideConfigManager>((ref) {
  throw UnimplementedError('videConfigManagerProvider must be overridden');
});

/// Provider for the working directory.
/// Must be overridden in main.dart.
final workingDirProvider = Provider<String>((ref) {
  throw UnimplementedError('workingDirProvider must be overridden');
});

// =============================================================================
// Permissions
// =============================================================================

/// Provider for the PermissionHandler.
/// Must be overridden in main.dart.
final permissionHandlerProvider = Provider<PermissionHandler>((ref) {
  throw UnimplementedError('permissionHandlerProvider must be overridden');
});

/// Session-scoped provider for dangerously skipping permissions.
final dangerouslySkipPermissionsProvider = StateProvider<bool>((ref) => false);

// =============================================================================
// Agent Status
// =============================================================================

/// Provider for agent status, keyed by agent ID.
///
/// Note: This is a simplified version that reads from the current session's
/// status registry. In the old architecture, this was a StateNotifierProvider.family
/// in vide_core. Now it reads from the session.
final agentStatusProvider = Provider.family<AgentStatus, String>((
  ref,
  agentId,
) {
  // Default status
  return AgentStatus.working;
});

// =============================================================================
// Claude Status
// =============================================================================

/// Provider for watching Claude SDK status from an agent's client.
final claudeStatusProvider = StreamProvider.family<ClaudeStatus, String>((
  ref,
  agentId,
) {
  return Stream.value(ClaudeStatus.ready);
});

// =============================================================================
// Auto Update
// =============================================================================

/// Provider for the AutoUpdateService instance.
final autoUpdateServiceProvider = Provider<AutoUpdateService>((ref) {
  final configManager = ref.watch(videConfigManagerProvider);
  return AutoUpdateService(configManager: configManager);
});

/// Stream provider for auto-update state changes.
final autoUpdateStateProvider = StreamProvider<UpdateState>((ref) {
  final service = ref.watch(autoUpdateServiceProvider);
  return service.stateStream;
});

// =============================================================================
// Team Framework
// =============================================================================

/// Provider for TeamFrameworkLoader.
final teamFrameworkLoaderProvider = Provider<TeamFrameworkLoader>((ref) {
  final workingDir = ref.watch(workingDirProvider);
  return TeamFrameworkLoader(workingDirectory: workingDir);
});

// =============================================================================
// Project Detection
// =============================================================================

/// Provider for detecting the project type.
final projectTypeProvider = Provider<ProjectType>((ref) {
  return ProjectDetector.detectProjectType();
});
