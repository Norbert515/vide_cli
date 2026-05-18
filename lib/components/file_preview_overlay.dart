import 'dart:io';
import 'dart:math' show max;

import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/text/text_layout_engine.dart';
import 'package:vide_core/vide_core.dart' show GitService;
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/shared/code_diff.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/shared/line_pairer.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/shared/side_by_side_code_diff.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/shared/side_by_side_models.dart';
import 'package:vide_cli/modules/agent_network/components/tool_invocations/shared/syntax_highlighter.dart';
import 'package:vide_cli/components/scrollbar_with_markers.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// Component that displays a file preview with syntax highlighting.
///
/// Shows the file content in a scrollable view with line numbers.
/// Press ESC or left-arrow to close the preview.
class FilePreviewOverlay extends StatefulComponent {
  final String filePath;
  final VoidCallback onClose;

  const FilePreviewOverlay({
    required this.filePath,
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
  final _gutterScrollController = ScrollController();
  bool _syncingScroll = false;

  /// Map of line numbers to their change type (1-indexed)
  Map<int, _LineChangeType> _lineChanges = {};

  /// Side-by-side diff rows computed from the unified diff.
  List<SideBySideDiffRow>? _sideBySideRows;
  bool _sideBySideHighlighted = false;
  /// Theme used for the last highlighting pass (to detect theme changes).
  VideThemeData? _highlightedWithTheme;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncGutterFromContent);
    _loadFile();
  }

  void _syncGutterFromContent() {
    if (_syncingScroll) return;
    // Skip sync in side-by-side mode where gutter is inline (no separate ListView).
    if (_sideBySideRows != null && _sideBySideRows!.isNotEmpty) return;
    _syncingScroll = true;
    _gutterScrollController.jumpTo(_scrollController.offset);
    _syncingScroll = false;
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
          _sideBySideRows = null;
          _sideBySideHighlighted = false;
        });
        // Load git diff info after file content
        _loadGitDiff();
      } else {
        setState(() {
          _fileContent = null;
          _error = 'File not found';
          _sideBySideRows = null;
          _sideBySideHighlighted = false;
        });
      }
    } catch (e) {
      setState(() {
        _fileContent = null;
        _error = 'Error reading file: $e';
        _sideBySideRows = null;
        _sideBySideHighlighted = false;
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

      final git = GitService(workingDirectory: dir.path);

      // Get the relative path from repo root
      final relativePath = component.filePath.substring(dir.path.length + 1);

      // Get diff for this specific file (both staged and unstaged)
      final unstagedDiff = await git.diff(files: [relativePath]);
      final stagedDiff = await git.diff(staged: true, files: [relativePath]);

      final changes = <int, _LineChangeType>{};

      // Parse the diff output to find changed lines
      _parseDiffOutput(unstagedDiff, changes);
      _parseDiffOutput(stagedDiff, changes);

      // Compute side-by-side rows from the combined diff against HEAD
      List<SideBySideDiffRow>? sideBySideRows;
      if (changes.isNotEmpty) {
        final headDiff = await git.runCommand(
          ['diff', 'HEAD', '--', relativePath],
        );
        if (headDiff.isNotEmpty) {
          final diffLines = DiffParser.parseUnifiedDiff(headDiff);
          // Filter out header lines (---, +++, @@) — they're not code content.
          final codeLines = diffLines.where((l) => l.type != DiffLineType.header).toList();
          sideBySideRows = LinePairer.pairLines(codeLines);
        }
      }

      if (mounted) {
        setState(() {
          _lineChanges = changes;
          _sideBySideRows = sideBySideRows;
          _sideBySideHighlighted = false;
        });
      }
    } catch (e) {
      // Silently ignore git errors - file might not be in a git repo
    }
  }

  /// Parses unified diff output and populates the changes map
  ///
  /// The algorithm tracks consecutive removed lines. When additions follow
  /// removals, those additions are marked as "modified" (replacement).
  /// Pure additions (with no preceding removals) are marked as "added".
  void _parseDiffOutput(String diffOutput, Map<int, _LineChangeType> changes) {
    if (diffOutput.isEmpty) return;

    final lines = diffOutput.split('\n');
    int? currentNewLine;
    int pendingRemovals = 0;

    for (final line in lines) {
      // Parse hunk header: @@ -oldStart,oldCount +newStart,newCount @@
      if (line.startsWith('@@')) {
        final match = RegExp(
          r'@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@',
        ).firstMatch(line);
        if (match != null) {
          currentNewLine = int.parse(match.group(1)!);
          pendingRemovals = 0;
        }
        continue;
      }

      if (currentNewLine == null) continue;

      if (line.startsWith('-') && !line.startsWith('---')) {
        // Removed line - track it but don't increment currentNewLine
        pendingRemovals++;
      } else if (line.startsWith('+') && !line.startsWith('+++')) {
        // Added line - mark as modified if it replaces removed content
        if (pendingRemovals > 0) {
          changes[currentNewLine] = _LineChangeType.modified;
          pendingRemovals--;
        } else {
          changes[currentNewLine] = _LineChangeType.added;
        }
        currentNewLine++;
      } else if (!line.startsWith('\\')) {
        // Context line (unchanged) - reset pending removals
        pendingRemovals = 0;
        currentNewLine++;
      }
    }
  }

  /// Builds the title span with filename and colored change summary.
  InlineSpan _buildTitleSpan(VideThemeData theme) {
    final fileName = component.filePath.split('/').last;

    if (_lineChanges.isEmpty) {
      return TextSpan(
        text: fileName,
        style: TextStyle(
          color: theme.base.primary,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final addedCount = _lineChanges.values
        .where((t) => t == _LineChangeType.added)
        .length;
    final modifiedCount = _lineChanges.values
        .where((t) => t == _LineChangeType.modified)
        .length;

    final children = <InlineSpan>[
      TextSpan(
        text: fileName,
        style: TextStyle(
          color: theme.base.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];

    if (addedCount > 0) {
      children.add(
        TextSpan(
          text: ' +$addedCount',
          style: TextStyle(
            color: theme.base.success,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (modifiedCount > 0) {
      children.add(
        TextSpan(
          text: ' ~$modifiedCount',
          style: TextStyle(
            color: theme.base.warning,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return TextSpan(children: children);
  }

  bool _handleKeyEvent(LogicalKey key) {
    switch (key) {
      case LogicalKey.escape:
        component.onClose();
        return true;
      case LogicalKey.arrowUp:
      case LogicalKey.keyK:
        _scrollController.scrollUp();
        return true;
      case LogicalKey.arrowDown:
      case LogicalKey.keyJ:
        _scrollController.scrollDown();
        return true;
      case LogicalKey.pageUp:
        _scrollController.pageUp();
        return true;
      case LogicalKey.pageDown:
        _scrollController.pageDown();
        return true;
      default:
        return false;
    }
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final borderColor = theme.base.primary;

    return KeyboardListener(
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Padding(
        padding: EdgeInsets.only(left: 1, right: 1, top: 1),
        child: Container(
          decoration: BoxDecoration(
            color: theme.base.surface,
            border: BoxBorder.all(color: borderColor),
            title: BorderTitle.rich(
              textSpan: _buildTitleSpan(theme),
              alignment: TitleAlignment.left,
            ),
          ),
          child: Column(
            children: [
              // Header with navigation hint
              Container(
                padding: EdgeInsets.symmetric(horizontal: 1),
                child: Row(
                  children: [
                    Expanded(child: SizedBox()),
                    Text(
                      'ESC to close',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // File content
              Expanded(child: _buildContent(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Component _buildContent(VideThemeData theme) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: theme.base.error)),
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

    // Show side-by-side diff when git changes exist
    if (_sideBySideRows != null && _sideBySideRows!.isNotEmpty) {
      return _buildSideBySideDiff(theme);
    }

    return _buildSinglePaneContent(theme);
  }

  /// Builds the single-pane file viewer (original behavior).
  Component _buildSinglePaneContent(VideThemeData theme) {
    final lines = _fileContent!.split('\n');
    final lineNumberWidth = lines.length.toString().length;
    final language = SyntaxHighlighter.detectLanguage(component.filePath);

    final borderColor = theme.base.primary;

    // gutter char (1) + line number digits + padding (1)
    final gutterWidth = 1 + lineNumberWidth + 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gutter: line numbers (not selectable)
        SizedBox(
          width: gutterWidth.toDouble(),
          child: ListView(
            lazy: false,
            controller: _gutterScrollController,
            children: [
              for (var i = 0; i < lines.length; i++)
                _buildGutter(i + 1, lineNumberWidth, theme, borderColor),
            ],
          ),
        ),
        // Content: selectable text
        Expanded(
          child: SelectionArea(
            onSelectionCompleted: ClipboardManager.copy,
            child: ScrollbarWithMarkers(
              controller: _scrollController,
              thumbVisibility: true,
              thumbColor: theme.base.primary,
              trackColor: theme.base.surface,
              markers: _buildScrollbarMarkers(lines.length, theme),
              child: ListView(
                lazy: false,
                controller: _scrollController,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    _buildContentLine(i + 1, lines[i], language, theme),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the side-by-side diff view with scrollbar.
  Component _buildSideBySideDiff(VideThemeData theme) {
    final rows = _sideBySideRows!;
    final language = SyntaxHighlighter.detectLanguage(component.filePath);

    // Pre-compute syntax highlighting lazily; invalidate on theme change.
    if (language != null && (!_sideBySideHighlighted || _highlightedWithTheme != theme)) {
      // Clear stale highlights when theme changed.
      if (_highlightedWithTheme != null && _highlightedWithTheme != theme) {
        for (final row in rows) {
          row.leftHighlighted = null;
          row.rightHighlighted = null;
        }
      }
      _computeSideBySideHighlighting(rows, language, theme);
      _sideBySideHighlighted = true;
      _highlightedWithTheme = theme;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Subtract scrollbar + marker width (2 chars) to avoid clipping right gutter.
        final totalWidth = constraints.maxWidth.toInt() - 2;
        if (totalWidth < 20) {
          return const Text('(too narrow for side-by-side diff)');
        }

        // Compute gutter width from the new file line count (most reliable).
        // Use the same width for both sides for visual symmetry.
        final newFileLines = _fileContent?.split('\n').length ?? 0;
        int maxLineNum = newFileLines;
        for (final row in rows) {
          if (row.leftLineNum != null && row.leftLineNum! > maxLineNum) {
            maxLineNum = row.leftLineNum!;
          }
          if (row.rightLineNum != null && row.rightLineNum! > maxLineNum) {
            maxLineNum = row.rightLineNum!;
          }
        }
        final gutterWidth = _gutterWidthForMax(maxLineNum);
        final leftGutterWidth = gutterWidth;
        final rightGutterWidth = gutterWidth;

        // Layout: [leftGutter][space][leftContent] | [rightContent][space][rightGutter]
        const separatorWidth = 3; // ' | '
        const spacers = 2; // one space after each gutter
        final chrome =
            leftGutterWidth + rightGutterWidth + separatorWidth + spacers;
        final contentBudget = totalWidth - chrome;
        if (contentBudget < 4) {
          return const Text('(too narrow for side-by-side diff)');
        }
        final leftContentWidth = contentBudget ~/ 2;
        final rightContentWidth = contentBudget - leftContentWidth;

        // Apply context folding (3 context lines).
        final displayRows = _foldContext(rows, 3);

        // Build scrollbar markers from side-by-side rows.
        final markers = <ScrollbarMarker>[];
        for (var i = 0; i < displayRows.length; i++) {
          final entry = displayRows[i];
          if (entry.isFold) continue;
          final rowType = entry.row!.type;
          final color = switch (rowType) {
            DiffRowType.added => theme.base.success,
            DiffRowType.deleted => theme.base.error,
            DiffRowType.modified => theme.base.warning,
            _ => null,
          };
          if (color != null) {
            markers.add(ScrollbarMarker(
              position: i,
              totalPositions: displayRows.length,
              color: color,
            ));
          }
        }

        return SelectionArea(
          onSelectionCompleted: ClipboardManager.copy,
          child: ScrollbarWithMarkers(
            controller: _scrollController,
            thumbVisibility: true,
            thumbColor: theme.base.primary,
            trackColor: theme.base.surface,
            markers: markers,
            child: ListView(
              lazy: false,
              controller: _scrollController,
              children: [
                for (final entry in displayRows)
                  if (entry.isFold)
                    _buildDiffFoldRow(theme, totalWidth, entry.hiddenCount)
                  else
                    _buildDiffRow(
                      theme,
                      entry.row!,
                      leftGutterWidth,
                      rightGutterWidth,
                      leftContentWidth,
                      rightContentWidth,
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pre-compute syntax highlighting for all side-by-side rows.
  void _computeSideBySideHighlighting(
    List<SideBySideDiffRow> rows,
    String language,
    VideThemeData theme,
  ) {
    for (final row in rows) {
      if (row.leftContent != null && row.leftHighlighted == null) {
        final bg = _diffBackgroundForSide(theme, row.type, isLeft: true);
        row.leftHighlighted = SyntaxHighlighter.highlightCode(
          row.leftContent!,
          language,
          backgroundColor: bg,
          syntaxColors: theme.syntax,
        );
        if (row.leftCharHighlights != null &&
            row.leftCharHighlights!.isNotEmpty) {
          row.leftHighlighted = applyCharHighlights(
            row.leftHighlighted!,
            row.leftCharHighlights!,
            theme.diff.removedCharHighlight,
          );
        }
      }
      if (row.rightContent != null && row.rightHighlighted == null) {
        final bg = _diffBackgroundForSide(theme, row.type, isLeft: false);
        row.rightHighlighted = SyntaxHighlighter.highlightCode(
          row.rightContent!,
          language,
          backgroundColor: bg,
          syntaxColors: theme.syntax,
        );
        if (row.rightCharHighlights != null &&
            row.rightCharHighlights!.isNotEmpty) {
          row.rightHighlighted = applyCharHighlights(
            row.rightHighlighted!,
            row.rightCharHighlights!,
            theme.diff.addedCharHighlight,
          );
        }
      }
    }
  }

  /// Get the background color for a side of a diff row.
  Color? _diffBackgroundForSide(
    VideThemeData theme,
    DiffRowType type, {
    required bool isLeft,
  }) {
    switch (type) {
      case DiffRowType.deleted:
        return isLeft ? theme.diff.removedBackground : null;
      case DiffRowType.added:
        return isLeft ? null : theme.diff.addedBackground;
      case DiffRowType.modified:
        return isLeft
            ? theme.diff.removedBackground
            : theme.diff.addedBackground;
      case DiffRowType.unchanged:
      case DiffRowType.header:
        return null;
    }
  }

  /// Compute gutter width from max line number.
  int _gutterWidthForMax(int maxLineNum) {
    if (maxLineNum <= 0) return 1;
    return maxLineNum.toString().length;
  }

  /// Context folding: collapse long runs of unchanged lines.
  List<_SideBySideDisplayEntry> _foldContext(
    List<SideBySideDiffRow> rows,
    int contextLines,
  ) {
    final result = <_SideBySideDisplayEntry>[];
    final threshold = 2 * contextLines + 1;

    int i = 0;
    while (i < rows.length) {
      if (rows[i].type == DiffRowType.unchanged) {
        final runStart = i;
        while (i < rows.length && rows[i].type == DiffRowType.unchanged) {
          i++;
        }
        final runLength = i - runStart;

        if (runLength > threshold) {
          for (int j = runStart; j < runStart + contextLines; j++) {
            result.add(_SideBySideDisplayEntry.row(rows[j]));
          }
          result.add(
            _SideBySideDisplayEntry.fold(runLength - 2 * contextLines),
          );
          for (int j = i - contextLines; j < i; j++) {
            result.add(_SideBySideDisplayEntry.row(rows[j]));
          }
        } else {
          for (int j = runStart; j < i; j++) {
            result.add(_SideBySideDisplayEntry.row(rows[j]));
          }
        }
      } else {
        result.add(_SideBySideDisplayEntry.row(rows[i]));
        i++;
      }
    }
    return result;
  }

  /// Build a single row in the side-by-side diff.
  Component _buildDiffRow(
    VideThemeData theme,
    SideBySideDiffRow row,
    int leftGutterWidth,
    int rightGutterWidth,
    int leftContentWidth,
    int rightContentWidth,
  ) {
    // Compute visual height for line wrapping alignment.
    final leftHeight = row.leftContent != null
        ? TextLayoutEngine.layout(
            row.leftContent!,
            TextLayoutConfig(maxWidth: leftContentWidth, softWrap: true),
          ).actualHeight
        : 1;
    final rightHeight = row.rightContent != null
        ? TextLayoutEngine.layout(
            row.rightContent!,
            TextLayoutConfig(maxWidth: rightContentWidth, softWrap: true),
          ).actualHeight
        : 1;
    final maxHeight = max(leftHeight, rightHeight);

    final leftBg = _diffBackgroundForSide(theme, row.type, isLeft: true);
    final rightBg = _diffBackgroundForSide(theme, row.type, isLeft: false);
    final gutterStyle = TextStyle(
      color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
    );

    return SizedBox(
      height: maxHeight.toDouble(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left gutter
          SizedBox(
            width: leftGutterWidth.toDouble(),
            child: Text(
              row.leftLineNum?.toString().padLeft(leftGutterWidth) ??
                  ' ' * leftGutterWidth,
              style: gutterStyle,
            ),
          ),
          // Space + left content
          SizedBox(
            width: (leftContentWidth + 1).toDouble(),
            child: Row(
              children: [
                Text(' ', style: TextStyle(backgroundColor: leftBg)),
                SizedBox(
                  width: leftContentWidth.toDouble(),
                  child: _buildDiffContentWidget(
                    theme,
                    row.leftContent,
                    row.leftHighlighted,
                    leftBg,
                  ),
                ),
              ],
            ),
          ),
          // Separator (fill full row height for wrapped lines)
          SizedBox(
            width: 3,
            child: Column(
              children: List.generate(
                maxHeight,
                (_) => Text(' │ ', style: TextStyle(color: theme.base.outline)),
              ),
            ),
          ),
          // Right content + space
          SizedBox(
            width: (rightContentWidth + 1).toDouble(),
            child: Row(
              children: [
                SizedBox(
                  width: rightContentWidth.toDouble(),
                  child: _buildDiffContentWidget(
                    theme,
                    row.rightContent,
                    row.rightHighlighted,
                    rightBg,
                  ),
                ),
                Text(' ', style: TextStyle(backgroundColor: rightBg)),
              ],
            ),
          ),
          // Right gutter
          SizedBox(
            width: rightGutterWidth.toDouble(),
            child: Text(
              row.rightLineNum?.toString().padLeft(rightGutterWidth) ??
                  ' ' * rightGutterWidth,
              style: gutterStyle,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a content widget for one side of a diff row.
  Component _buildDiffContentWidget(
    VideThemeData theme,
    String? content,
    TextSpan? highlighted,
    Color? backgroundColor,
  ) {
    if (content == null) {
      return const Text('');
    }
    if (highlighted != null) {
      return RichText(text: highlighted, softWrap: true);
    }
    return Text(
      content,
      style: TextStyle(
        color: theme.base.onSurface,
        backgroundColor: backgroundColor,
      ),
      overflow: TextOverflow.visible,
    );
  }

  /// Build a fold marker row for hidden unchanged lines.
  Component _buildDiffFoldRow(
    VideThemeData theme,
    int totalWidth,
    int hiddenCount,
  ) {
    final label = '···· $hiddenCount lines hidden ····';
    final padding = totalWidth - label.length;
    final leftPad = padding > 0 ? padding ~/ 2 : 0;
    return SizedBox(
      height: 1,
      width: totalWidth.toDouble(),
      child: Text(
        '${' ' * leftPad}$label',
        style: TextStyle(color: theme.base.outline),
      ),
    );
  }

  /// Converts [_lineChanges] into [ScrollbarMarker]s for the scrollbar.
  List<ScrollbarMarker> _buildScrollbarMarkers(
    int totalLines,
    VideThemeData theme,
  ) {
    return _lineChanges.entries.map((entry) {
      final color = switch (entry.value) {
        _LineChangeType.added => theme.base.success,
        _LineChangeType.modified => theme.base.warning,
        _LineChangeType.unchanged => theme.base.onSurface,
      };
      return ScrollbarMarker(
        position: entry.key - 1, // convert from 1-indexed to 0-indexed
        totalPositions: totalLines,
        color: color,
      );
    }).toList();
  }

  /// Builds the gutter column for a line (change indicator + line number).
  Component _buildGutter(
    int lineNumber,
    int lineNumberWidth,
    VideThemeData theme,
    Color borderColor,
  ) {
    final lineNumStr = lineNumber.toString().padLeft(lineNumberWidth);
    final changeType = _lineChanges[lineNumber];

    String gutterChar;
    Color gutterColor;
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
        gutterColor = borderColor;
        lineBackground = null;
    }

    final gutter = Row(
      children: [
        Text(gutterChar, style: TextStyle(color: gutterColor)),
        Container(
          padding: EdgeInsets.only(right: 1),
          child: Text(
            lineNumStr,
            style: TextStyle(
              color: changeType != null
                  ? gutterColor.withOpacity(0.8)
                  : theme.base.onSurface.withOpacity(TextOpacity.tertiary),
            ),
          ),
        ),
      ],
    );

    if (lineBackground != null) {
      return Container(
        decoration: BoxDecoration(color: lineBackground),
        child: gutter,
      );
    }

    return gutter;
  }

  /// Builds the content portion of a line (selectable text).
  Component _buildContentLine(
    int lineNumber,
    String lineContent,
    String? language,
    VideThemeData theme,
  ) {
    final changeType = _lineChanges[lineNumber];

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

    if (changeType == _LineChangeType.added) {
      return Container(
        decoration: BoxDecoration(color: theme.base.success.withOpacity(0.1)),
        child: contentComponent,
      );
    }

    if (changeType == _LineChangeType.modified) {
      return Container(
        decoration: BoxDecoration(color: theme.base.warning.withOpacity(0.1)),
        child: contentComponent,
      );
    }

    return contentComponent;
  }
}

/// Entry in the side-by-side display list after context folding.
class _SideBySideDisplayEntry {
  final SideBySideDiffRow? row;
  final int hiddenCount;

  const _SideBySideDisplayEntry.row(this.row) : hiddenCount = 0;
  const _SideBySideDisplayEntry.fold(this.hiddenCount) : row = null;

  bool get isFold => row == null;
}
