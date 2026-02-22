import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_cli/main.dart' show daemonModeEnabledProvider;
import 'package:vide_cli/modules/settings/components/settings_card.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';
import 'package:vide_cli/modules/settings/components/settings_text_input.dart';

/// Daemon settings: mode toggle, host, and port.
class DaemonSettingsSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const DaemonSettingsSection({
    required this.focused,
    required this.onExit,
    super.key,
  });

  @override
  State<DaemonSettingsSection> createState() => _DaemonSettingsSectionState();
}

class _DaemonSettingsSectionState extends State<DaemonSettingsSection> {
  int _selectedIndex = 0;

  // [0] = Daemon mode, [1] = Host, [2] = Port
  static const int _totalItems = 3;

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

    if (_editingIndex != null) {
      if (event.logicalKey == LogicalKey.escape) {
        setState(() => _editingIndex = null);
        return true;
      }
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
    if (_selectedIndex == 1) {
      final configManager = context.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      _hostController.text = settings.daemonHost;
      setState(() => _editingIndex = 1);
    } else if (_selectedIndex == 2) {
      final configManager = context.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      _portController.text = settings.daemonPort.toString();
      setState(() => _editingIndex = 2);
    } else {
      _toggleCurrentItem();
    }
  }

  void _toggleCurrentItem() {
    if (_selectedIndex != 0) return;
    final container = ProviderScope.containerOf(context);
    final configManager = container.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final newValue = !settings.daemonModeEnabled;
    configManager.writeGlobalSettings(
      settings.copyWith(daemonModeEnabled: newValue),
    );
    container.read(daemonModeEnabledProvider.notifier).state = newValue;
    setState(() {});
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
    final daemonModeEnabled = settings.daemonModeEnabled;

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        _selectedIndex == 0 &&
                        _editingIndex == null,
                    onTap: () {
                      setState(() => _selectedIndex = 0);
                      _activateCurrentItem();
                    },
                  ),
                  SettingsTextInput(
                    label: 'Host',
                    description: 'Hostname or IP address of the daemon',
                    value: settings.daemonHost,
                    isSelected:
                        component.focused &&
                        _selectedIndex == 1 &&
                        _editingIndex == null,
                    isEditing: _editingIndex == 1,
                    controller: _hostController,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
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
                        _selectedIndex == 2 &&
                        _editingIndex == null,
                    isEditing: _editingIndex == 2,
                    controller: _portController,
                    onTap: () {
                      setState(() => _selectedIndex = 2);
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
