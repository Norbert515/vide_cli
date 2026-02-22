import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_cli/main.dart'
    show ideModeEnabledProvider, gitSidebarEnabledProvider;
import 'package:vide_cli/modules/settings/components/settings_card.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';

/// General settings: Interface toggles (IDE Mode, Git Sidebar, Streaming).
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

  // [0] = IDE mode, [1] = Git sidebar, [2] = Streaming
  static const int _totalItems = 3;

  bool _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return false;

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
      _toggleCurrentItem();
      return true;
    }

    return false;
  }

  void _toggleCurrentItem() {
    final container = ProviderScope.containerOf(context);
    final configManager = container.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();

    if (_selectedIndex == 0) {
      final newValue = !settings.ideModeEnabled;
      configManager.writeGlobalSettings(
        settings.copyWith(ideModeEnabled: newValue),
      );
      container.read(ideModeEnabledProvider.notifier).state = newValue;
      setState(() {});
    } else if (_selectedIndex == 1) {
      final newValue = !settings.gitSidebarEnabled;
      configManager.writeGlobalSettings(
        settings.copyWith(gitSidebarEnabled: newValue),
      );
      container.read(gitSidebarEnabledProvider.notifier).state = newValue;
      setState(() {});
    } else if (_selectedIndex == 2) {
      configManager.writeGlobalSettings(
        settings.copyWith(enableStreaming: !settings.enableStreaming),
      );
      setState(() {});
    }
  }

  @override
  Component build(BuildContext context) {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final ideModeEnabled = settings.ideModeEnabled;
    final gitSidebarEnabled = settings.gitSidebarEnabled;
    final streamingEnabled = settings.enableStreaming;

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    isSelected: component.focused && _selectedIndex == 2,
                    onTap: () {
                      setState(() => _selectedIndex = 2);
                      _toggleCurrentItem();
                    },
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
