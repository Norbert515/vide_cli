import 'dart:io';

import 'package:riverpod/riverpod.dart';

enum ProjectType { flutter, dart, nocterm, unknown }

final projecTypeProvider = Provider<ProjectType>((ref) {
  return ProjectDetector.detectProjectType();
});

/// Utility for detecting project types based on file markers
class ProjectDetector {
  /// Detect if a directory is a Dart or Flutter project
  ///
  /// Checks for the presence of pubspec.yaml file
  static bool isDartProject([String? path]) {
    final dir = path ?? Directory.current.path;
    return File('$dir/pubspec.yaml').existsSync();
  }

  /// Detect if a directory is specifically a Flutter project
  ///
  /// Checks for pubspec.yaml and Flutter SDK dependency
  static bool isFlutterProject([String? path]) {
    if (!isDartProject(path)) return false;

    final dir = path ?? Directory.current.path;
    final pubspec = File('$dir/pubspec.yaml');

    try {
      final content = pubspec.readAsStringSync();

      // Check for Flutter SDK dependency or flutter configuration
      return content.contains(RegExp(r'^\s*sdk:\s*flutter', multiLine: true)) ||
          content.contains(RegExp(r'^\s*flutter:', multiLine: true));
    } catch (e) {
      return false;
    }
  }

  /// Detect if a directory is a Nocterm project
  ///
  /// Checks for pubspec.yaml and nocterm dependency
  static bool isNoctermProject([String? path]) {
    if (!isDartProject(path)) return false;

    final dir = path ?? Directory.current.path;
    final pubspec = File('$dir/pubspec.yaml');

    try {
      final content = pubspec.readAsStringSync();

      // Check for nocterm dependency in dependencies section
      return content.contains(RegExp(r'^\s*nocterm:', multiLine: true));
    } catch (e) {
      return false;
    }
  }

  /// Detect the project type as a ProjectType enum
  ///
  /// Detection priority:
  /// 1. If nocterm dependency found → ProjectType.nocterm
  /// 2. Else if Flutter project → ProjectType.flutter
  /// 3. Else if Dart project → ProjectType.dart
  /// 4. Else → ProjectType.unknown
  static ProjectType detectProjectType([String? path]) {
    if (isNoctermProject(path)) return ProjectType.nocterm;
    if (isFlutterProject(path)) return ProjectType.flutter;
    if (isDartProject(path)) return ProjectType.dart;
    return ProjectType.unknown;
  }

  /// Get a descriptive project type string
  static String getProjectType([String? path]) {
    if (isFlutterProject(path)) return 'Flutter';
    if (isDartProject(path)) return 'Dart';
    return 'Unknown';
  }
}
