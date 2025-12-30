// Tool to generate bundled runtime_ai_dev_tools code for synthetic main generator.
//
// Usage: dart run tool/generate_bundled_devtools.dart
// (Run from packages/flutter_runtime_mcp directory or repo root)

import 'dart:io';
import 'package:path/path.dart' as path;

/// Source files in dependency order
const _sourceFiles = [
  'lib/src/tap_visualization.dart',
  'lib/src/screenshot_extension.dart',
  'lib/src/tap_extension.dart',
  'lib/src/type_extension.dart',
  'lib/src/scroll_extension.dart',
  'lib/src/debug_overlay_wrapper.dart',
  'lib/src/debug_binding.dart',
];

/// Renames to apply (public -> private)
const _renames = {
  'TapVisualizationService': '_TapVisualizationService',
  'registerScreenshotExtension': '_registerScreenshotExtension',
  'registerTapExtension': '_registerTapExtension',
  'registerTypeExtension': '_registerTypeExtension',
  'registerScrollExtension': '_registerScrollExtension',
  'DebugOverlayWrapper': '_DebugOverlayWrapper',
  'DebugWidgetsFlutterBinding': '_DebugWidgetsFlutterBinding',
};

/// Patterns to remove from code
final _removePatterns = [
  // Remove print statements (matches print('...');)
  RegExp(r"print\([^;]*\);[ \t]*\n?", multiLine: true),
];


/// Required imports that might be aliased
const _requiredImports = [
  "dart:convert",
  "dart:developer",
  "dart:io",
  "dart:ui",
  "package:flutter/material.dart",
  "package:flutter/rendering.dart",
  "package:flutter/services.dart",
  "package:flutter/widgets.dart",
];

/// Export patterns to remove
final _exportPatterns = [
  RegExp(r"^export\s+[^;]+;.*$", multiLine: true),
];

/// Flutter/Dart SDK imports to keep (deduplicated in output)
final _flutterDartImports = <String>{};

void main() async {
  // Determine paths based on script location
  final scriptPath = Platform.script.toFilePath();
  final scriptDir = path.dirname(scriptPath);

  // Handle different execution contexts
  String flutterRuntimeMcpDir;
  String runtimeAiDevToolsDir;

  if (scriptPath.contains('tool/generate_bundled_devtools.dart')) {
    // Running from: dart run tool/generate_bundled_devtools.dart
    // Script is in packages/flutter_runtime_mcp/tool/
    flutterRuntimeMcpDir = path.dirname(scriptDir);
    runtimeAiDevToolsDir =
        path.join(path.dirname(flutterRuntimeMcpDir), 'runtime_ai_dev_tools');
  } else {
    // Try to find directories relative to current working directory
    final cwd = Directory.current.path;
    if (cwd.endsWith('packages/flutter_runtime_mcp')) {
      flutterRuntimeMcpDir = cwd;
      runtimeAiDevToolsDir = path.join(path.dirname(cwd), 'runtime_ai_dev_tools');
    } else {
      // Assume running from repo root
      flutterRuntimeMcpDir = path.join(cwd, 'packages', 'flutter_runtime_mcp');
      runtimeAiDevToolsDir = path.join(cwd, 'packages', 'runtime_ai_dev_tools');
    }
  }

  // Verify directories exist
  if (!Directory(runtimeAiDevToolsDir).existsSync()) {
    print('Error: runtime_ai_dev_tools directory not found at: $runtimeAiDevToolsDir');
    exit(1);
  }
  if (!Directory(flutterRuntimeMcpDir).existsSync()) {
    print('Error: flutter_runtime_mcp directory not found at: $flutterRuntimeMcpDir');
    exit(1);
  }

  print('Reading source files from: $runtimeAiDevToolsDir');
  print('Will write output to: $flutterRuntimeMcpDir/lib/src/bundled_devtools_code.dart');

  // Process each source file
  final processedFiles = <String, String>{};
  for (final sourceFile in _sourceFiles) {
    final filePath = path.join(runtimeAiDevToolsDir, sourceFile);
    if (!File(filePath).existsSync()) {
      print('Warning: Source file not found: $filePath');
      continue;
    }

    final content = await File(filePath).readAsString();
    final processed = _processSourceFile(sourceFile, content);
    processedFiles[sourceFile] = processed;
    print('  Processed: $sourceFile');
  }

  // Generate output
  final output = _generateOutput(processedFiles);

  // Write output file
  final outputPath = path.join(flutterRuntimeMcpDir, 'lib', 'src', 'bundled_devtools_code.dart');
  await File(outputPath).writeAsString(output);
  print('\nGenerated: $outputPath');
  print('Done!');
}

String _processSourceFile(String fileName, String content) {
  var processed = content;

  // Extract Flutter/Dart SDK imports (handle aliased imports too)
  final importMatches = RegExp(r"^import\s+'([^']+)'(?:\s+as\s+\w+)?;.*$", multiLine: true)
      .allMatches(processed);
  for (final match in importMatches) {
    final importPath = match.group(1)!;
    if (importPath.startsWith('dart:') ||
        importPath.startsWith('package:flutter/')) {
      _flutterDartImports.add(importPath);
    }
  }

  // Remove all imports (they'll be consolidated at the top)
  processed = processed.replaceAll(
      RegExp(r"^import\s+[^;]+;.*\n?", multiLine: true), '');

  // Remove exports
  for (final pattern in _exportPatterns) {
    processed = processed.replaceAll(pattern, '');
  }

  // Remove print statements
  for (final pattern in _removePatterns) {
    processed = processed.replaceAll(pattern, '');
  }

  // Apply renames
  for (final entry in _renames.entries) {
    // Use word boundaries to avoid partial matches
    processed = processed.replaceAll(
      RegExp(r'\b' + entry.key + r'\b'),
      entry.value,
    );
  }

  // Rename cos/sin to _bundledCos/_bundledSin (avoid conflicts with dart:math)
  processed = processed.replaceAll(RegExp(r'\bcos\('), '_bundledCos(');
  processed = processed.replaceAll(RegExp(r'\bsin\('), '_bundledSin(');

  // Clean up excessive blank lines
  processed = processed.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return processed.trim();
}

String _generateOutput(Map<String, String> processedFiles) {
  final buffer = StringBuffer();

  // Header
  buffer.writeln('// GENERATED FILE - DO NOT EDIT');
  buffer.writeln('// Generated by: dart run tool/generate_bundled_devtools.dart');
  buffer.writeln('// Source: packages/runtime_ai_dev_tools/lib/');
  buffer.writeln();

  // Ensure all required imports are included
  for (final imp in _requiredImports) {
    _flutterDartImports.add(imp);
  }

  // Generate imports string with proper aliases
  final sortedImports = _flutterDartImports.toList()..sort();
  final importsBuffer = StringBuffer();
  importsBuffer.writeln('// === Bundled runtime_ai_dev_tools imports ===');
  for (final imp in sortedImports) {
    if (imp == 'dart:developer') {
      importsBuffer.writeln("import '$imp' as developer;");
    } else if (imp == 'dart:ui') {
      importsBuffer.writeln("import '$imp' as ui;");
    } else {
      importsBuffer.writeln("import '$imp';");
    }
  }

  // Check if imports contain triple quotes (unlikely but handle it)
  final importsContent = importsBuffer.toString().trim();

  buffer.writeln('/// Bundled imports for the synthetic main file');
  buffer.writeln("const String bundledImports = '''");
  buffer.writeln(importsContent);
  buffer.writeln("''';");
  buffer.writeln();

  // Generate code string
  final codeBuffer = StringBuffer();
  codeBuffer.writeln('// === Bundled runtime_ai_dev_tools code ===');
  codeBuffer.writeln();

  for (final entry in processedFiles.entries) {
    final fileName = entry.key.split('/').last;
    codeBuffer.writeln('// ============================================================================');
    codeBuffer.writeln('// $fileName');
    codeBuffer.writeln('// ============================================================================');
    codeBuffer.writeln();
    codeBuffer.writeln(entry.value);
    codeBuffer.writeln();
  }

  // For the code, we need to escape any occurrences of ''' in the content
  var codeContent = codeBuffer.toString().trim();

  // Check if code contains raw string terminators
  if (codeContent.contains("'''")) {
    // This is problematic - we need to handle it
    print("Warning: Source code contains triple quotes, using alternative escaping");
    // Replace ''' with a placeholder and document it
    codeContent = codeContent.replaceAll("'''", "' ' '");
  }

  buffer.writeln('/// Bundled runtime_ai_dev_tools code for the synthetic main file');
  buffer.writeln("const String bundledCode = r'''");
  buffer.writeln(codeContent);
  buffer.writeln("''';");

  return buffer.toString();
}
