import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vide_client/vide_client.dart';

import '../../data/repositories/server_registry.dart';
import 'files_state.dart';
import 'widgets/diff_bottom_sheet.dart';
import 'widgets/file_list_tile.dart';
import 'widgets/git_status_header.dart';

class FilesScreen extends ConsumerWidget {
  final String sessionId;
  final String workingDirectory;

  const FilesScreen({
    super.key,
    required this.sessionId,
    required this.workingDirectory,
  });

  String _basename(String path) {
    final parts = path.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }

  Future<void> _showDiff(
    BuildContext context,
    WidgetRef ref,
    FileEntry entry,
    String rootPath,
  ) async {
    final registry = ref.read(serverRegistryProvider.notifier);
    final connected = registry.connectedEntries;
    if (connected.isEmpty) return;
    final client = connected.first.client;
    if (client == null) return;

    final fullDiff = await client.gitDiff(rootPath);
    final fileDiff = _filterDiffForFile(fullDiff, entry.path, rootPath);

    if (!context.mounted) return;

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

  String _filterDiffForFile(String fullDiff, String filePath, String rootPath) {
    final relativePath = filePath.length > rootPath.length &&
            filePath.startsWith(rootPath)
        ? filePath.substring(rootPath.length + 1)
        : filePath;

    final lines = fullDiff.split('\n');
    final buffer = StringBuffer();
    var inTargetSection = false;

    for (final line in lines) {
      if (line.startsWith('diff --git ')) {
        inTargetSection = line.contains('a/$relativePath') &&
            line.contains('b/$relativePath');
      }
      if (inTargetSection) {
        buffer.writeln(line);
      }
    }

    return buffer.toString().trimRight();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filesNotifierProvider(workingDirectory));
    final notifier = ref.read(filesNotifierProvider(workingDirectory).notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_basename(state.currentPath)),
        actions: [
          if (!state.isAtRoot)
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: () => notifier.navigateUp(),
              tooltip: 'Parent directory',
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.gitStatus != null)
            GitStatusHeader(gitStatus: state.gitStatus!),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load files',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                state.error!,
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonal(
                              onPressed: () => notifier.refresh(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : state.entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open_outlined,
                                  size: 48,
                                  color: colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Empty directory',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => notifier.refresh(),
                            child: ListView.separated(
                              itemCount: state.entries.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 0.5,
                                indent: 48,
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                              itemBuilder: (context, index) {
                                final entry = state.entries[index];
                                final isChanged = _isFileChanged(
                                  entry,
                                  state.rootPath,
                                  state.gitStatus,
                                );
                                return FileListTile(
                                  entry: entry,
                                  rootPath: state.rootPath,
                                  gitStatus: state.gitStatus,
                                  onTap: () {
                                    if (entry.isDirectory) {
                                      notifier.navigateTo(entry.path);
                                    } else if (isChanged) {
                                      _showDiff(
                                        context,
                                        ref,
                                        entry,
                                        state.rootPath,
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  bool _isFileChanged(
    FileEntry entry,
    String rootPath,
    GitStatusInfo? gitStatus,
  ) {
    if (gitStatus == null) return false;
    if (entry.path.length <= rootPath.length) return false;
    final relativePath = entry.path.startsWith(rootPath)
        ? entry.path.substring(rootPath.length + 1)
        : entry.path;
    return gitStatus.allChangedFiles.contains(relativePath);
  }
}
