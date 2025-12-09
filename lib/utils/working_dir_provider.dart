import 'package:riverpod/riverpod.dart';
import 'package:path/path.dart' as path;

final workingDirProvider = Provider<String>((ref) {
  return path.current;
});
