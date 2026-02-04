import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_cli/main.dart'
    show
        ideModeEnabledProvider,
        gitSidebarEnabledProvider,
        daemonModeEnabledProvider;
import 'package:vide_cli/modules/settings/components/section_header.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';
import 'package:vide_cli/modules/settings/components/settings_text_input.dart';

/// General settings content (IDE mode, git sidebar, streaming).
class GeneralSettingsSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const GeneralSettingsSection({
    required this.focused,
    required this.onExit,
    super.key,
  });

  @override
  State<GeneralSettingsSection> createState() => _GeneralSettingsSectionState();
}

class _GeneralSettingsSectionState extends State<GeneralSettingsSection> {
  int _selectedIndex = 0;

  // Settings items:
  // [0] = IDE mode, [1] = Git sidebar, [2] = Daemon mode,
  // [3] = Daemon host, [4] = Daemon port, [5] = Streaming
  static const int _totalItems = 6;

  // Editing state for text inputs
  int? _editingIndex;
  final _hostController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return;

    // If editing a text field, let the TextField handle input
    if (_editingIndex != null) {
      if (event.logicalKey == LogicalKey.escape) {
        setState(() => _editingIndex = null);
      }
      // Let TextField handle other keys including Enter
      return;
    }

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
      }
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < _totalItems - 1) {
        setState(() => _selectedIndex++);
      }
    } else if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.escape) {
      component.onExit();
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _activateCurrentItem();
    }
  }

  void _activateCurrentItem() {
    // For text input items, start editing mode
    if (_selectedIndex == 3) {
      // Daemon host
      final configManager = context.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      _hostController.text = settings.daemonHost;
      setState(() => _editingIndex = 3);
    } else if (_selectedIndex == 4) {
      // Daemon port
      final configManager = context.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      _portController.text = settings.daemonPort.toString();
      setState(() => _editingIndex = 4);
    } else {
      _toggleCurrentItem();
    }
  }

  void _toggleCurrentItem() {
    final container = ProviderScope.containerOf(context);
    final configManager = container.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();

    if (_selectedIndex == 0) {
      // Toggle IDE mode
      final newValue = !settings.ideModeEnabled;
      configManager.writeGlobalSettings(
        settings.copyWith(ideModeEnabled: newValue),
      );
      container.read(ideModeEnabledProvider.notifier).state = newValue;
      setState(() {}); // Rebuild to show new state
    } else if (_selectedIndex == 1) {
      // Toggle Git sidebar
      final newValue = !settings.gitSidebarEnabled;
      configManager.writeGlobalSettings(
        settings.copyWith(gitSidebarEnabled: newValue),
      );
      container.read(gitSidebarEnabledProvider.notifier).state = newValue;
      setState(() {}); // Rebuild to show new state
    } else if (_selectedIndex == 2) {
      // Toggle Daemon mode
      final newValue = !settings.daemonModeEnabled;
      configManager.writeGlobalSettings(
        settings.copyWith(daemonModeEnabled: newValue),
      );
      container.read(daemonModeEnabledProvider.notifier).state = newValue;
      setState(() {}); // Rebuild to show new state
    } else if (_selectedIndex == 5) {
      // Toggle streaming (index 5 now)
      configManager.writeGlobalSettings(
        settings.copyWith(enableStreaming: !settings.enableStreaming),
      );
      setState(() {}); // Rebuild to show new state
    }
  }

  void _saveDaemonHost(String value) {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    configManager.writeGlobalSettings(
      settings.copyWith(
        daemonHost: value.trim().isEmpty ? '127.0.0.1' : value.trim(),
      ),
    );
    setState(() => _editingIndex = null);
  }

  void _saveDaemonPort(String value) {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final port = int.tryParse(value.trim()) ?? 8080;
    configManager.writeGlobalSettings(settings.copyWith(daemonPort: port));
    setState(() => _editingIndex = null);
  }

  @override
  Component build(BuildContext context) {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final ideModeEnabled = settings.ideModeEnabled;
    final gitSidebarEnabled = settings.gitSidebarEnabled;
    final daemonModeEnabled = settings.daemonModeEnabled;
    final streamingEnabled = settings.enableStreaming;

    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        _handleKeyEvent(event);
        return true;
      },
      child: Padding(
        padding: EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'General Settings'),
            SizedBox(height: 2),

            // IDE Mode toggle
            SettingsToggleItem(
              label: 'IDE Mode',
              description: 'Show agent sidebar',
              value: ideModeEnabled,
              isSelected: component.focused && _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                _toggleCurrentItem();
              },
            ),

            // Git Sidebar toggle
            SettingsToggleItem(
              label: 'Git Sidebar',
              description: 'Show git status (requires git repo)',
              value: gitSidebarEnabled,
              isSelected: component.focused && _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                _toggleCurrentItem();
              },
            ),

            // Daemon Mode toggle
            SettingsToggleItem(
              label: 'Daemon Mode',
              description: 'Run sessions on a persistent daemon process',
              value: daemonModeEnabled,
              isSelected:
                  component.focused &&
                  _selectedIndex == 2 &&
                  _editingIndex == null,
              onTap: () {
                setState(() => _selectedIndex = 2);
                _activateCurrentItem();
              },
            ),

            // Daemon Host input
            SettingsTextInput(
              label: 'Daemon Host',
              description: 'Hostname or IP address of the daemon',
              value: settings.daemonHost,
              isSelected:
                  component.focused &&
                  _selectedIndex == 3 &&
                  _editingIndex == null,
              isEditing: _editingIndex == 3,
              controller: _hostController,
              onTap: () {
                setState(() => _selectedIndex = 3);
                _activateCurrentItem();
              },
              onSubmitted: _saveDaemonHost,
            ),

            // Daemon Port input
            SettingsTextInput(
              label: 'Daemon Port',
              description: 'Port number of the daemon',
              value: settings.daemonPort.toString(),
              isSelected:
                  component.focused &&
                  _selectedIndex == 4 &&
                  _editingIndex == null,
              isEditing: _editingIndex == 4,
              controller: _portController,
              onTap: () {
                setState(() => _selectedIndex = 4);
                _activateCurrentItem();
              },
              onSubmitted: _saveDaemonPort,
            ),

            // Streaming toggle
            SettingsToggleItem(
              label: 'Streaming',
              description: 'Stream responses in real-time',
              value: streamingEnabled,
              isSelected:
                  component.focused &&
                  _selectedIndex == 5 &&
                  _editingIndex == null,
              onTap: () {
                setState(() => _selectedIndex = 5);
                _activateCurrentItem();
              },
            ),
          ],
        ),
      ),
    );
  }
}
