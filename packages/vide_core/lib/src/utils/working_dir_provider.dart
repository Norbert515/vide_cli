import 'package:riverpod/riverpod.dart';
import '../vide_core_config.dart';

/// Working directory provider. Reads from [videCoreConfigProvider].
final workingDirProvider = Provider<String>((ref) {
  return ref.watch(videCoreConfigProvider).workingDirectory;
});
