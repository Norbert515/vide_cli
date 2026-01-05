import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/components/rich_text.dart';
import 'package:vide_core/mcp/git/git_client.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/utils/syntax_highlighter.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// Component that displays a file preview with syntax highlighting.
///
/// Shows the file content in a scrollable view with line numbers.
/// Press ESC or left-arrow to close the preview.
class FilePreviewOverlay extends StatefulComponent {
  final String filePath;
  final bool focused;
  final VoidCallback onClose;

  const FilePreviewOverlay({
    required this.filePath,
    this.focused = true,
    required this.onClose,
    super.key,
  });

  @override
  State<FilePreviewOverlay> createState() => _FilePreviewOverlayState();
}

/// Represents the type of change for a line
enum _LineChangeType {
  added,
  modified,
  // ignore: unused_field
  unchanged,
}

class _FilePreviewOverlayState extends State<FilePreviewOverlay> {
  String? _fileContent;
  String? _error;
  final _scrollController = ScrollController();

  /// Map of line numbers to their change type (1-indexed)
  Map<int, _LineChangeType> _lineChanges = {};

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void didUpdateComponent(FilePreviewOverlay old) {
    super.didUpdateComponent(old);
    if (component.filePath != old.filePath) {
      _loadFile();
    }
  }

  void _loadFile() {
    try {
      final file = File(component.filePath);
      if (file.existsSync()) {
        setState(() {
          _fileContent = file.readAsStringSync();
          _error = null;
        });
        // Load git diff info after file content
        _loadGitDiff();
      } else {
        setState(() {
          _fileContent = null;
          _error = 'File not found';
        });
      }
    } catch (e) {
      setState(() {
        _fileContent = null;
        _error = 'Error reading file: $e';
      });
    }
  }

  /// Loads git diff information for the current file
  Future<void> _loadGitDiff() async {
    try {
      // Get the repo root directory from the file path
      final file = File(component.filePath);
      var dir = file.parent;

      // Find git root by looking for .git directory
      while (dir.path != dir.parent.path) {
        if (Directory('${dir.path}/.git').existsSync()) {
          break;
        }
        dir = dir.parent;
      }

      final client = GitClient(workingDirectory: dir.path);

      // Get the relative path from repo root
      final relativePath = component.filePath.substring(dir.path.length + 1);

      // Get diff for this specific file (both staged and unstaged)
      final unstagedDiff = await client.diff(files: [relativePath]);
      final stagedDiff = await client.diff(staged: true, files: [relativePath]);

      final changes = <int, _LineChangeType>{};

      // Parse the diff output to find changed lines
      _parseDiffOutput(unstagedDiff, changes);
      _parseDiffOutput(stagedDiff, changes);

      if (mounted) {
        setState(() {
          _lineChanges = changes;
        });
      }
    } catch (e) {
      // Silently ignore git errors - file might not be in a git repo
    }
  }

  /// Parses unified diff output and populates the changes map
  void _parseDiffOutput(String diffOutput, Map<int, _LineChangeType> changes) {
    if (diffOutput.isEmpty) return;

    final lines = diffOutput.split('\n');
    int? currentNewLine;

    for (final line in lines) {
      // Parse hunk header: @@ -oldStart,oldCount +newStart,newCount @@
      if (line.startsWith('@@')) {
        final match = RegExp(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@').firstMatch(line);
        if (match != null) {
          currentNewLine = int.parse(match.group(1)!);
        }
        continue;
      }

      if (currentNewLine == null) continue;

      if (line.startsWith('+') && !line.startsWith('+++')) {
        // Added line
        changes[currentNewLine] = _LineChangeType.added;
        currentNewLine++;
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        // Removed line - mark next line as modified if it exists
        // Don't increment currentNewLine for removed lines
      } else if (!line.startsWith('\\')) {
        // Context line (unchanged)
        currentNewLine++;
      }
    }
  }

  void _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.escape ||
        event.logicalKey == LogicalKey.arrowLeft) {
      // ESC or left arrow closes the preview and returns to sidebar
      component.onClose();
    } else if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      _scrollController.scrollUp();
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      _scrollController.scrollDown();
    } else if (event.logicalKey == LogicalKey.pageUp) {
      _scrollController.pageUp();
    } else if (event.logicalKey == LogicalKey.pageDown) {
      _scrollController.pageDown();
    } else if (event.logicalKey == LogicalKey.home) {
      _scrollController.scrollToStart();
    } else if (event.logicalKey == LogicalKey.end) {
      _scrollController.scrollToEnd();
    }
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final fileName = component.filePath.split('/').last;
    final borderColor = component.focused ? theme.base.primary : theme.base.outline;

    return Padding(
      padding: EdgeInsets.only(left: 1, right: 1, top: 1),
      child: Focusable(
        focused: component.focused,
        onKeyEvent: (event) {
          _handleKeyEvent(event);
          return true;
        },
        child: Container(
          decoration: BoxDecoration(
            color: theme.base.surface,
            border: BoxBorder.all(color: borderColor),
            title: BorderTitle(
              text: fileName,
              style: TextStyle(
                color: theme.base.primary,
                fontWeight: FontWeight.bold,
              ),
              alignment: TitleAlignment.left,
            ),
          ),
          child: Column(
            children: [
              // Header with change summary and navigation hint
              Container(
                padding: EdgeInsets.symmetric(horizontal: 1),
                child: Row(
                  children: [
                    // Change summary
                    if (_lineChanges.isNotEmpty) ...[
                      Text(
                        '+${_lineChanges.length}',
                        style: TextStyle(
                          color: theme.base.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 1),
                    ],
                    Expanded(child: SizedBox()),
                    Text(
                      '← to close',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                      ),
                    ),
                  ],
                ),
              ),
              // File content
              Expanded(
                child: _buildContent(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Component _buildContent(VideThemeData theme) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: theme.base.error),
        ),
      );
    }

    if (_fileContent == null) {
      return Center(
        child: Text(
          'Loading...',
          style: TextStyle(
            color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
          ),
        ),
      );
    }

    final lines = _fileContent!.split('\n');
    final lineNumberWidth = lines.length.toString().length;
    final language = SyntaxHighlighter.detectLanguage(component.filePath);

    return ListView(
      controller: _scrollController,
      children: [
        for (var i = 0; i < lines.length; i++)
          _buildLine(i + 1, lines[i], lineNumberWidth, language, theme),
      ],
    );
  }

  Component _buildLine(
    int lineNumber,
    String lineContent,
    int lineNumberWidth,
    String? language,
    VideThemeData theme,
  ) {
    final lineNumStr = lineNumber.toString().padLeft(lineNumberWidth);
    final changeType = _lineChanges[lineNumber];

    // Determine gutter indicator and colors based on change type
    String gutterChar;
    Color? gutterColor;
    Color? lineBackground;

    switch (changeType) {
      case _LineChangeType.added:
        gutterChar = '│';
        gutterColor = theme.base.success;
        lineBackground = theme.base.success.withOpacity(0.1);
        break;
      case _LineChangeType.modified:
        gutterChar = '│';
        gutterColor = theme.base.warning;
        lineBackground = theme.base.warning.withOpacity(0.1);
        break;
      default:
        gutterChar = ' ';
        gutterColor = null;
        lineBackground = null;
    }

    // Highlight the line content if language is detected
    Component contentComponent;
    if (language != null && lineContent.isNotEmpty) {
      final highlightedSpan = SyntaxHighlighter.highlightCode(
        lineContent,
        language,
        syntaxColors: theme.syntax,
      );
      contentComponent = RichText(text: highlightedSpan);
    } else {
      contentComponent = Text(
        lineContent.isEmpty ? ' ' : lineContent,
        style: TextStyle(color: theme.syntax.plain),
      );
    }

    final lineRow = Row(
      children: [
        // Git change indicator (gutter)
        Text(
          gutterChar,
          style: TextStyle(
            color: gutterColor ?? theme.base.outline.withOpacity(0.3),
          ),
        ),
        // Line number
        Container(
          padding: EdgeInsets.only(right: 1),
          child: Text(
            lineNumStr,
            style: TextStyle(
              color: changeType != null
                  ? gutterColor!.withOpacity(0.8)
                  : theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
        ),
        // Line content
        Expanded(child: contentComponent),
      ],
    );

    // Wrap with background color if line has changes
    if (lineBackground != null) {
      return Container(
        decoration: BoxDecoration(color: lineBackground),
        child: lineRow,
      );
    }

    return lineRow;
  }
}
