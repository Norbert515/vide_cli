import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_cli/modules/settings/components/settings_card.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';

/// Debug settings: Codex backend toggle.
class DebugSettingsSection extends StatefulComponent {
  final bool focused;
  final VoidCallback onExit;

  const DebugSettingsSection({
    required this.focused,
    required this.onExit,
    super.key,
  });

  @override
  State<DebugSettingsSection> createState() => _DebugSettingsSectionState();
}

class _DebugSettingsSectionState extends State<DebugSettingsSection> {
  int _selectedIndex = 0;

  // [0] = Codex backend
  static const int _totalItems = 1;

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
    if (_selectedIndex != 0) return;
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    configManager.writeGlobalSettings(
      settings.copyWith(useCodexBackend: !settings.useCodexBackend),
    );
    setState(() {});
  }

  @override
  Component build(BuildContext context) {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final useCodexBackend = settings.useCodexBackend;

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsCard(
              title: 'Debug',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsToggleItem(
                    label: 'Codex Backend',
                    description:
                        'Use OpenAI Codex instead of Claude (restart required)',
                    value: useCodexBackend,
                    isSelected: component.focused && _selectedIndex == 0,
                    onTap: () {
                      setState(() => _selectedIndex = 0);
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
