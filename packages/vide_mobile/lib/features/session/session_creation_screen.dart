import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/vide_colors.dart';
import '../../data/local/settings_storage.dart';

import '../../data/repositories/server_registry.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models/server_connection.dart';
import 'session_creation_state.dart';

/// Screen for creating a new session.
class SessionCreationScreen extends ConsumerStatefulWidget {
  const SessionCreationScreen({super.key});

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
    final storage = ref.read(settingsStorageProvider.notifier);
    final lastDir = await storage.getLastWorkingDirectory();

    if (lastDir != null) {
      ref
          .read(sessionCreationNotifierProvider.notifier)
          .setWorkingDirectory(lastDir);
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
        model: 'sonnet',
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
                  onSelected: (dir) {
                    ref
                        .read(sessionCreationNotifierProvider.notifier)
                        .setWorkingDirectory(dir);
                  },
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
  final ValueChanged<String> onSelected;

  const _WorkingDirectorySelector({
    required this.selectedDirectory,
    required this.enabled,
    required this.onSelected,
  });

  @override
  ConsumerState<_WorkingDirectorySelector> createState() =>
      _WorkingDirectorySelectorState();
}

class _WorkingDirectorySelectorState
    extends ConsumerState<_WorkingDirectorySelector> {
  bool _showCustomInput = false;
  final _customController = TextEditingController();
  List<String> _recentDirs = [];

  @override
  void initState() {
    super.initState();
    _loadRecentDirectories();
  }

  Future<void> _loadRecentDirectories() async {
    final storage = ref.read(settingsStorageProvider.notifier);
    final dirs = await storage.getRecentWorkingDirectories();
    if (mounted) {
      setState(() => _recentDirs = dirs);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final dir in _recentDirs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DirectoryRow(
              path: dir,
              isSelected: dir == widget.selectedDirectory,
              onTap: widget.enabled ? () => widget.onSelected(dir) : null,
            ),
          ),
        if (_showCustomInput)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customController,
                    decoration: const InputDecoration(
                      hintText: '/path/to/project',
                      isDense: true,
                    ),
                    autofocus: true,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        widget.onSelected(value);
                        setState(() => _showCustomInput = false);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    if (_customController.text.isNotEmpty) {
                      widget.onSelected(_customController.text);
                      setState(() => _showCustomInput = false);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _showCustomInput = false);
                    _customController.clear();
                  },
                ),
              ],
            ),
          )
        else
          TextButton.icon(
            onPressed: widget.enabled
                ? () => setState(() => _showCustomInput = true)
                : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Enter custom path'),
          ),
      ],
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  final String path;
  final bool isSelected;
  final VoidCallback? onTap;

  const _DirectoryRow({
    required this.path,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? videColors.accentSubtle : null,
          border: Border.all(
            color: isSelected ? videColors.accent : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 18,
              color: videColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                path,
                style: TextStyle(
                  color: isSelected ? videColors.accent : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: 18, color: videColors.accent),
          ],
        ),
      ),
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
