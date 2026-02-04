import 'package:riverpod/riverpod.dart';

/// Session-scoped provider for dangerously skipping permissions.
///
/// When true, ALL permission checks are bypassed for the current session.
/// This is set via CLI flag `--dangerously-skip-permissions` and applies
/// only to the current session (not persisted).
///
/// DANGEROUS: Only use in sandboxed environments (Docker, VMs) where
/// filesystem isolation protects the host system.
///
/// The global setting in VideGlobalSettings is a separate, persistent
/// preference that can be toggled in the settings UI. The ClaudeClientFactory
/// checks BOTH this provider (session override) and the global setting.
final dangerouslySkipPermissionsProvider = StateProvider<bool>((ref) => false);
