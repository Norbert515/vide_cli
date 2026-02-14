import 'package:riverpod/riverpod.dart';
import '../vide_core_config.dart';

/// Skip permissions flag. Reads from [videCoreConfigProvider].
///
/// When true, ALL permission checks are bypassed for the current session.
/// DANGEROUS: Only use in sandboxed environments (Docker, VMs).
final dangerouslySkipPermissionsProvider = Provider<bool>((ref) {
  return ref.watch(videCoreConfigProvider).dangerouslySkipPermissions;
});
