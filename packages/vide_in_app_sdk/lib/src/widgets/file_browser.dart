import 'package:flutter/material.dart';
import 'package:vide_client/vide_client.dart';
import 'package:vide_mobile/core/theme/tokens.dart';
import 'package:vide_mobile/core/theme/vide_colors.dart';
import 'package:vide_mobile/features/files/widgets/file_content_bottom_sheet.dart';
import 'package:vide_mobile/features/files/widgets/file_list_tile.dart';
import 'package:vide_mobile/features/files/widgets/git_status_header.dart';
import 'package:vide_mobile/features/files/utils/diff_utils.dart';
import 'package:vide_mobile/features/files/widgets/diff_bottom_sheet.dart';

/// File browser for the in-app SDK.
///
/// Uses [VideClient] directly (no Riverpod) to list directories, show file
/// content, and display git change indicators.
class FileBrowser extends StatefulWidget {
  final VideClient client;
  final String workingDirectory;

  const FileBrowser({
    super.key,
    required this.client,
    required this.workingDirectory,
  });

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  late String _currentPath;
  List<FileEntry> _entries = [];
  GitStatusInfo? _gitStatus;
  bool _isLoading = true;
  String? _error;

  bool get _isAtRoot => _currentPath == widget.workingDirectory;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.workingDirectory;
    _load(_currentPath);
  }

  Future<void> _load(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.client.listDirectory(parent: path),
        widget.client.gitStatus(widget.workingDirectory, detailed: true),
      ]);

      final entries = results[0] as List<FileEntry>;
      entries.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _currentPath = path;
          _entries = entries;
          _gitStatus = results[1] as GitStatusInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _navigateUp() {
    if (_isAtRoot) return;
    var path = _currentPath;
    while (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash <= 0) return;
    _load(path.substring(0, lastSlash));
  }

  Future<void> _showFileContent(FileEntry entry) async {
    final isChanged = _isFileChanged(entry);

    try {
      final content = await widget.client.readFileContent(entry.path);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => FileContentBottomSheet(
          fileName: entry.name,
          content: content,
          isChanged: isChanged,
          onViewDiff: isChanged
              ? () {
                  Navigator.of(sheetContext).pop();
                  _showDiff(entry);
                }
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to read file: $e')),
      );
    }
  }

  Future<void> _showDiff(FileEntry entry) async {
    final fullDiff = await widget.client.gitDiff(widget.workingDirectory);
    final relativePath =
        toRelativePath(entry.path, widget.workingDirectory);
    final fileDiff = filterDiffForFile(fullDiff, relativePath);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DiffBottomSheet(
        fileName: entry.name,
        diff: fileDiff,
      ),
    );
  }

  bool _isFileChanged(FileEntry entry) {
    if (_gitStatus == null) return false;
    final root = widget.workingDirectory;
    if (entry.path.length <= root.length) return false;
    final relativePath = entry.path.startsWith(root)
        ? entry.path.substring(root.length + 1)
        : entry.path;
    return _gitStatus!.allChangedFiles.contains(relativePath);
  }

  String _basename(String path) {
    final parts = path.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Column(
      children: [
        // Navigation header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VideSpacing.sm,
            vertical: VideSpacing.xs,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _isAtRoot ? null : _navigateUp,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_upward,
                    size: 20,
                    color: _isAtRoot
                        ? videColors.textTertiary
                        : videColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _basename(_currentPath),
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _load(_currentPath),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.refresh,
                    size: 20,
                    color: videColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Git status header
        if (_gitStatus != null) GitStatusHeader(gitStatus: _gitStatus!),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 32, color: colorScheme.error),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: videColors.textSecondary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: () => _load(_currentPath),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _entries.isEmpty
                      ? Center(
                          child: Text(
                            'Empty directory',
                            style: TextStyle(color: videColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 0.5,
                            indent: 48,
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            return FileListTile(
                              entry: entry,
                              rootPath: widget.workingDirectory,
                              gitStatus: _gitStatus,
                              onTap: () {
                                if (entry.isDirectory) {
                                  _load(entry.path);
                                } else {
                                  _showFileContent(entry);
                                }
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
