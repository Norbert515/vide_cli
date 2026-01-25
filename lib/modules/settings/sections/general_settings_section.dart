import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_cli/main.dart' show ideModeEnabledProvider, gitSidebarEnabledProvider;
import 'package:vide_cli/modules/settings/components/section_header.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';

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

  // Settings items: [0] = IDE mode toggle, [1] = Git sidebar toggle, [2] = Streaming toggle
  static const int _totalItems = 3;

  void _handleKeyEvent(KeyboardEvent event) {
    if (!component.focused) return;

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
      // Toggle streaming
      configManager.writeGlobalSettings(
        settings.copyWith(enableStreaming: !settings.enableStreaming),
      );
      setState(() {}); // Rebuild to show new state
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

            // Streaming toggle
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
    );
  }
}
