import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vide_client/vide_client.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/vide_colors.dart';
import '../../data/local/settings_storage.dart';

import '../../data/repositories/server_registry.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models/server_connection.dart';
import 'session_creation_state.dart';

/// Screen for creating a new session.
class SessionCreationScreen extends ConsumerStatefulWidget {
  final SessionCreationArgs? args;

  const SessionCreationScreen({super.key, this.args});

  @override
  ConsumerState<SessionCreationScreen> createState() =>
      _SessionCreationScreenState();
}

class _SessionCreationScreenState extends ConsumerState<SessionCreationScreen> {
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    _loadDefaults();
  }

  void _onMessageChanged() {
    ref
        .read(sessionCreationNotifierProvider.notifier)
        .setInitialMessage(_messageController.text);
  }

  Future<void> _loadDefaults() async {
    final notifier = ref.read(sessionCreationNotifierProvider.notifier);
    final storage = ref.read(settingsStorageProvider.notifier);
    final args = widget.args;

    // Pre-fill from args (quick-start) or fall back to last used directory
    final dir = args?.workingDirectory ?? await storage.getLastWorkingDirectory();
    if (dir != null) {
      notifier.setWorkingDirectory(dir);
    }

    // Pre-fill server from args or cached path-server mapping
    if (args?.serverId != null) {
      notifier.setSelectedServerId(args!.serverId);
    } else if (dir != null) {
      final cachedServerId = await storage.getServerForPath(dir);
      if (cachedServerId != null) {
        notifier.setSelectedServerId(cachedServerId);
      }
    }
  }

  Future<void> _onDirectoryChanged(String dir) async {
    final notifier = ref.read(sessionCreationNotifierProvider.notifier);
    notifier.setWorkingDirectory(dir);

    // Auto-select the cached server for this directory
    final storage = ref.read(settingsStorageProvider.notifier);
    final cachedServerId = await storage.getServerForPath(dir);
    if (cachedServerId != null && mounted) {
      notifier.setSelectedServerId(cachedServerId);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    final notifier = ref.read(sessionCreationNotifierProvider.notifier);

    if (!notifier.validate()) {
      final error = ref.read(sessionCreationNotifierProvider).error;
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
      return;
    }

    notifier.setIsCreating(true);

    try {
      final state = ref.read(sessionCreationNotifierProvider);
      final sessionRepo = ref.read(sessionRepositoryProvider.notifier);
      final settingsStorage = ref.read(settingsStorageProvider.notifier);

      final session = await sessionRepo.createSession(
        initialMessage: state.initialMessage,
        workingDirectory: state.workingDirectory,
        team: state.team,
        serverId: state.selectedServerId,
      );

      await settingsStorage.addRecentWorkingDirectory(state.workingDirectory);

      if (mounted) {
        // The initial message is already sent to the server via createSession.
        // RemoteVideSession tracks processing state internally — the chat
        // screen reads session.state.isProcessing directly.
        notifier.setIsCreating(false);
        context.go(AppRoutes.sessionPath(session.id));
      }
    } catch (e) {
      if (mounted) {
        notifier.setIsCreating(false);
        final videColors = Theme.of(context).extension<VideThemeColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create session: $e'),
            backgroundColor: videColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionCreationNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.sessions),
        ),
      ),
      floatingActionButton: FilledButton.icon(
        onPressed: state.isCreating ? null : _createSession,
        icon: state.isCreating
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.play_arrow_rounded),
        label: Text(state.isCreating ? 'Creating...' : 'Start Session'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(160, 56),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Initial message
                Text(
                  'Initial Message',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'What would you like help with?',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  minLines: 3,
                  textInputAction: TextInputAction.newline,
                  enabled: !state.isCreating,
                ),
                // Server selection (only when multiple servers connected)
                Builder(builder: (context) {
                  final registryState = ref.watch(serverRegistryProvider);
                  final connectedServers = registryState.entries
                      .where((e) =>
                          e.value.status == ServerHealthStatus.connected)
                      .toList();

                  if (connectedServers.length <= 1) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'Server',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 8),
                      ...connectedServers.map((entry) {
                        final serverId = entry.key;
                        final server = entry.value;
                        final isSelected =
                            state.selectedServerId == serverId ||
                                (state.selectedServerId == null &&
                                    entry == connectedServers.first);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: !state.isCreating
                                ? () => ref
                                    .read(sessionCreationNotifierProvider
                                        .notifier)
                                    .setSelectedServerId(serverId)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? videColors.accentSubtle
                                    : null,
                                border: Border.all(
                                  color: isSelected
                                      ? videColors.accent
                                      : colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.dns_outlined,
                                    size: 18,
                                    color: isSelected
                                        ? videColors.accent
                                        : videColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      server.connection.displayName,
                                      style: TextStyle(
                                        color: isSelected
                                            ? videColors.accent
                                            : colorScheme.onSurface,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check,
                                        size: 18, color: videColors.accent),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
                const SizedBox(height: 24),
                // Working directory
                Text(
                  'Working Directory',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                _WorkingDirectorySelector(
                  selectedDirectory: state.workingDirectory,
                  enabled: !state.isCreating,
                  selectedServerId: state.selectedServerId,
                  onSelected: (dir) => _onDirectoryChanged(dir),
                ),
                const SizedBox(height: 24),
                // Permission mode
                Text(
                  'Permission Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                _PermissionModeSelector(
                  selectedMode: state.permissionMode,
                  enabled: !state.isCreating,
                  onSelected: (mode) {
                    ref
                        .read(sessionCreationNotifierProvider.notifier)
                        .setPermissionMode(mode);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkingDirectorySelector extends ConsumerStatefulWidget {
  final String selectedDirectory;
  final bool enabled;
  final String? selectedServerId;
  final ValueChanged<String> onSelected;

  const _WorkingDirectorySelector({
    required this.selectedDirectory,
    required this.enabled,
    required this.selectedServerId,
    required this.onSelected,
  });

  @override
  ConsumerState<_WorkingDirectorySelector> createState() =>
      _WorkingDirectorySelectorState();
}

class _WorkingDirectorySelectorState
    extends ConsumerState<_WorkingDirectorySelector> {
  List<String> _recentDirs = [];
  final _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecentDirectories();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentDirectories() async {
    final storage = ref.read(settingsStorageProvider.notifier);
    final dirs = await storage.getRecentWorkingDirectories();
    if (mounted) {
      setState(() => _recentDirs = dirs);
    }
  }

  VideClient? _getSelectedClient() {
    final registry = ref.read(serverRegistryProvider.notifier);
    if (widget.selectedServerId != null) {
      return registry.getClient(widget.selectedServerId!);
    }
    // Fallback to first connected server
    final connected = registry.connectedEntries;
    if (connected.isEmpty) return null;
    return connected.first.client;
  }

  Future<void> _openFolderPicker() async {
    final client = _getSelectedClient();
    if (client == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No server connected')),
        );
      }
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FolderPickerSheet(client: client),
    );

    if (result != null) {
      widget.onSelected(result);
    }
  }

  void _showDirectoryOptions() {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final hasServer = _getSelectedClient() != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_recentDirs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Recent',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: videColors.textSecondary,
                  ),
                ),
              ),
              for (final dir in _recentDirs)
                ListTile(
                  leading: Icon(
                    Icons.folder_outlined,
                    color: dir == widget.selectedDirectory
                        ? videColors.accent
                        : videColors.textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    _folderName(dir),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: dir == widget.selectedDirectory
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: dir == widget.selectedDirectory
                          ? videColors.accent
                          : colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    dir,
                    style: TextStyle(
                      fontSize: 11,
                      color: videColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: dir == widget.selectedDirectory
                      ? Icon(Icons.check, size: 18, color: videColors.accent)
                      : null,
                  dense: true,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelected(dir);
                  },
                ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: Icon(
                Icons.folder_open,
                size: 20,
                color: hasServer ? null : videColors.textSecondary,
              ),
              title: Text(
                hasServer ? 'Browse server...' : 'Browse (no server)',
                style: TextStyle(
                  color: hasServer ? null : videColors.textSecondary,
                ),
              ),
              enabled: hasServer,
              onTap: () {
                Navigator.pop(context);
                _openFolderPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, size: 20),
              title: const Text('Enter path manually'),
              onTap: () {
                Navigator.pop(context);
                _showManualPathInput();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showManualPathInput() {
    _pathController.text = widget.selectedDirectory;
    _pathController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _pathController.text.length,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Working Directory'),
        content: TextField(
          controller: _pathController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '/path/to/project',
            labelText: 'Path',
          ),
          onSubmitted: (value) {
            final path = value.trim();
            if (path.isNotEmpty) {
              widget.onSelected(path);
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final path = _pathController.text.trim();
              if (path.isNotEmpty) {
                widget.onSelected(path);
              }
              Navigator.pop(context);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final hasValue = widget.selectedDirectory.isNotEmpty;

    return InkWell(
      onTap: widget.enabled ? _showDirectoryOptions : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 18,
              color: videColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: hasValue
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _folderName(widget.selectedDirectory),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.selectedDirectory,
                          style: TextStyle(
                            color: videColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Text(
                      'Select a directory',
                      style: TextStyle(color: videColors.textSecondary),
                    ),
            ),
            Icon(
              Icons.unfold_more,
              size: 18,
              color: videColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  static String _folderName(String path) {
    final parts = path.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }
}

class _FolderPickerSheet extends StatefulWidget {
  final VideClient client;

  const _FolderPickerSheet({required this.client});

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  String? _currentPath;
  List<FileEntry> _entries = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<FileEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    final query = _searchQuery.toLowerCase();
    return _entries.where((e) => e.name.toLowerCase().contains(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadDirectory(null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory(String? path) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _searchQuery = '';
      _searchController.clear();
    });

    try {
      final entries = await widget.client.listDirectory(parent: path);
      final dirs = entries.where((e) => e.isDirectory).toList();

      if (mounted) {
        setState(() {
          _currentPath = path ?? _deriveParentPath(entries);
          _entries = dirs;
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

  /// Derives the parent path from entries when no explicit path was given
  /// (initial load). Falls back to '/' if entries are empty.
  String _deriveParentPath(List<FileEntry> entries) {
    if (entries.isEmpty) return '/';
    final firstPath = entries.first.path;
    final lastSlash = firstPath.lastIndexOf('/');
    if (lastSlash <= 0) return '/';
    return firstPath.substring(0, lastSlash);
  }

  String? get _parentPath {
    if (_currentPath == null || _currentPath == '/') return null;
    final lastSlash = _currentPath!.lastIndexOf('/');
    if (lastSlash <= 0) return '/';
    return _currentPath!.substring(0, lastSlash);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header with path and select button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 20),
                      onPressed: _parentPath != null
                          ? () => _loadDirectory(_parentPath)
                          : null,
                      tooltip: 'Parent directory',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentPath ?? '...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _currentPath != null
                          ? () => Navigator.of(context).pop(_currentPath)
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Select'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              // Search bar
              if (!_isLoading && _error == null && _entries.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search folders...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                  ),
                ),
              // Directory listing
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _error!,
                                style: TextStyle(color: videColors.error),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _filteredEntries.isEmpty
                            ? Center(
                                child: Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No matching folders'
                                      : 'No subdirectories',
                                  style: TextStyle(
                                    color: videColors.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _filteredEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = _filteredEntries[index];
                                  return ListTile(
                                    leading: Icon(
                                      Icons.folder_outlined,
                                      color: videColors.accent,
                                      size: 20,
                                    ),
                                    title: Text(
                                      entry.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    dense: true,
                                    onTap: () =>
                                        _loadDirectory(entry.path),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _PermissionModeSelector extends StatelessWidget {
  final PermissionMode selectedMode;
  final bool enabled;
  final ValueChanged<PermissionMode> onSelected;

  const _PermissionModeSelector({
    required this.selectedMode,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: PermissionMode.values.map((mode) {
        return RadioListTile<PermissionMode>(
          title: Text(mode.displayName),
          subtitle: Text(
            mode == PermissionMode.defaultMode
                ? 'You will be asked to approve each tool use'
                : 'Tools will be executed without asking',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: mode,
          groupValue: selectedMode,
          onChanged: enabled ? (value) => onSelected(value!) : null,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }
}
