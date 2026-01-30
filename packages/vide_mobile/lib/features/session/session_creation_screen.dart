import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import 'session_creation_state.dart';

/// Screen for creating a new session.
class SessionCreationScreen extends ConsumerStatefulWidget {
  const SessionCreationScreen({super.key});

  @override
  ConsumerState<SessionCreationScreen> createState() => _SessionCreationScreenState();
}

class _SessionCreationScreenState extends ConsumerState<SessionCreationScreen> {
  final _messageController = TextEditingController();
  final _directoryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    _directoryController.addListener(_onDirectoryChanged);
  }

  void _onMessageChanged() {
    ref.read(sessionCreationNotifierProvider.notifier).setInitialMessage(_messageController.text);
  }

  void _onDirectoryChanged() {
    ref.read(sessionCreationNotifierProvider.notifier).setWorkingDirectory(_directoryController.text);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _directoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDirectory() async {
    // Show a dialog to enter directory path manually
    // In a real app, this would use a file picker
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _DirectoryInputDialog(
        initialPath: _directoryController.text,
      ),
    );

    if (result != null) {
      _directoryController.text = result;
    }
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

    // TODO: Implement actual session creation via API
    // For now, simulate with a delay and navigate to a placeholder session
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      notifier.setIsCreating(false);
      // Navigate to session screen with a placeholder ID
      context.go(AppRoutes.sessionPath('new-session'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionCreationNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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
                TextFormField(
                  controller: _directoryController,
                  decoration: InputDecoration(
                    hintText: '/path/to/project',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open_outlined),
                      onPressed: state.isCreating ? null : _selectDirectory,
                      tooltip: 'Browse',
                    ),
                  ),
                  readOnly: true,
                  onTap: state.isCreating ? null : _selectDirectory,
                  enabled: !state.isCreating,
                ),
                const SizedBox(height: 24),
                // Model selection
                Text(
                  'Model',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _ModelSelector(
                  selectedModel: state.model,
                  enabled: !state.isCreating,
                  onSelected: (model) {
                    ref.read(sessionCreationNotifierProvider.notifier).setModel(model);
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
                    ref.read(sessionCreationNotifierProvider.notifier).setPermissionMode(mode);
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

class _ModelSelector extends StatelessWidget {
  final ClaudeModel selectedModel;
  final bool enabled;
  final ValueChanged<ClaudeModel> onSelected;

  const _ModelSelector({
    required this.selectedModel,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SegmentedButton<ClaudeModel>(
      segments: ClaudeModel.values.map((model) {
        return ButtonSegment<ClaudeModel>(
          value: model,
          label: Text(model.displayName.replaceFirst('Claude ', '')),
          icon: Icon(
            model == ClaudeModel.opus
                ? Icons.auto_awesome
                : model == ClaudeModel.haiku
                    ? Icons.bolt
                    : Icons.assistant,
            size: 18,
          ),
        );
      }).toList(),
      selected: {selectedModel},
      onSelectionChanged: enabled ? (selection) => onSelected(selection.first) : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return null;
        }),
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

class _DirectoryInputDialog extends StatefulWidget {
  final String initialPath;

  const _DirectoryInputDialog({required this.initialPath});

  @override
  State<_DirectoryInputDialog> createState() => _DirectoryInputDialogState();
}

class _DirectoryInputDialogState extends State<_DirectoryInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPath);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Working Directory'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: '/path/to/project',
          helperText: 'Enter the absolute path to your project',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
