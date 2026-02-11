import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_cli/main.dart'
    show
        ideModeEnabledProvider,
        gitSidebarEnabledProvider,
        daemonModeEnabledProvider;
import 'package:vide_cli/modules/settings/components/settings_card.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';
import 'package:vide_cli/modules/settings/components/settings_text_input.dart';

/// General settings content split into Interface and Daemon cards.
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
  // [0] = IDE mode, [1] = Git sidebar, [2] = Streaming
  // [3] = Daemon mode, [4] = Daemon host, [5] = Daemon port
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

  bool _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return false;

    // If editing a text field, let the TextField handle input
    if (_editingIndex != null) {
      if (event.logicalKey == LogicalKey.escape) {
        setState(() => _editingIndex = null);
        return true;
      }
      // Let TextField handle other keys including Enter
      return false;
    }

    if (event.logicalKey == LogicalKey.arrowUp ||
        event.logicalKey == LogicalKey.keyK) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.keyJ) {
      if (_selectedIndex < _totalItems - 1) {
        setState(() => _selectedIndex++);
      }
      return true;
    } else if (event.logicalKey == LogicalKey.arrowLeft ||
        event.logicalKey == LogicalKey.escape) {
      component.onExit();
      return true;
    } else if (event.logicalKey == LogicalKey.enter ||
        event.logicalKey == LogicalKey.space) {
      _activateCurrentItem();
      return true;
    }

    return false;
  }

  void _activateCurrentItem() {
    // For text input items, start editing mode
    if (_selectedIndex == 4) {
      // Daemon host
      final configManager = context.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      _hostController.text = settings.daemonHost;
      setState(() => _editingIndex = 4);
    } else if (_selectedIndex == 5) {
      // Daemon port
      final configManager = context.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      _portController.text = settings.daemonPort.toString();
      setState(() => _editingIndex = 5);
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
      setState(() {});
    } else if (_selectedIndex == 1) {
      // Toggle Git sidebar
      final newValue = !settings.gitSidebarEnabled;
      configManager.writeGlobalSettings(
        settings.copyWith(gitSidebarEnabled: newValue),
      );
      container.read(gitSidebarEnabledProvider.notifier).state = newValue;
      setState(() {});
    } else if (_selectedIndex == 2) {
      // Toggle streaming
      configManager.writeGlobalSettings(
        settings.copyWith(enableStreaming: !settings.enableStreaming),
      );
      setState(() {});
    } else if (_selectedIndex == 3) {
      // Toggle Daemon mode
      final newValue = !settings.daemonModeEnabled;
      configManager.writeGlobalSettings(
        settings.copyWith(daemonModeEnabled: newValue),
      );
      container.read(daemonModeEnabledProvider.notifier).state = newValue;
      setState(() {});
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
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Interface card: IDE Mode, Git Sidebar, Streaming
            SettingsCard(
              title: 'Interface',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  SettingsToggleItem(
                    label: 'Git Sidebar',
                    description: 'Show git status',
                    value: gitSidebarEnabled,
                    isSelected: component.focused && _selectedIndex == 1,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                      _toggleCurrentItem();
                    },
                  ),
                  SettingsToggleItem(
                    label: 'Streaming',
                    description: 'Stream responses in real-time',
                    value: streamingEnabled,
                    isSelected:
                        component.focused &&
                        _selectedIndex == 2 &&
                        _editingIndex == null,
                    onTap: () {
                      setState(() => _selectedIndex = 2);
                      _activateCurrentItem();
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 1),

            // Daemon card: Daemon Mode, Host, Port
            SettingsCard(
              title: 'Daemon',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsToggleItem(
                    label: 'Daemon Mode',
                    description: 'Run sessions on a persistent daemon process',
                    value: daemonModeEnabled,
                    isSelected:
                        component.focused &&
                        _selectedIndex == 3 &&
                        _editingIndex == null,
                    onTap: () {
                      setState(() => _selectedIndex = 3);
                      _activateCurrentItem();
                    },
                  ),
                  SettingsTextInput(
                    label: 'Host',
                    description: 'Hostname or IP address of the daemon',
                    value: settings.daemonHost,
                    isSelected:
                        component.focused &&
                        _selectedIndex == 4 &&
                        _editingIndex == null,
                    isEditing: _editingIndex == 4,
                    controller: _hostController,
                    onTap: () {
                      setState(() => _selectedIndex = 4);
                      _activateCurrentItem();
                    },
                    onSubmitted: _saveDaemonHost,
                  ),
                  SettingsTextInput(
                    label: 'Port',
                    description: 'Port number of the daemon',
                    value: settings.daemonPort.toString(),
                    isSelected:
                        component.focused &&
                        _selectedIndex == 5 &&
                        _editingIndex == null,
                    isEditing: _editingIndex == 5,
                    controller: _portController,
                    onTap: () {
                      setState(() => _selectedIndex = 5);
                      _activateCurrentItem();
                    },
                    onSubmitted: _saveDaemonPort,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
