import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart' show videConfigManagerProvider;
import 'package:vide_cli/main.dart'
    show ideModeEnabledProvider, gitSidebarEnabledProvider;
import 'package:vide_cli/modules/settings/components/settings_card.dart';
import 'package:vide_cli/modules/settings/components/settings_text_input.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';
import 'package:vide_cli/services/sound_service.dart';

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

  // [0] = IDE mode, [1] = Git sidebar, [2] = Streaming, [3] = Show Thinking,
  // [4] = Sound Notifications, [5] = Complete Sound, [6] = Attention Sound
  static const int _totalItems = 7;

  int? _editingIndex;
  final _completeSoundController = TextEditingController();
  final _attentionSoundController = TextEditingController();

  @override
  void dispose() {
    _completeSoundController.dispose();
    _attentionSoundController.dispose();
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
    if (_selectedIndex == 5) {
      final configManager = context.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      _completeSoundController.text = settings.customTaskCompleteSound ?? '';
      setState(() => _editingIndex = 5);
    } else if (_selectedIndex == 6) {
      final configManager = context.read(videConfigManagerProvider);
      final settings = configManager.readGlobalSettings();
      _attentionSoundController.text =
          settings.customAttentionNeededSound ?? '';
      setState(() => _editingIndex = 6);
    } else {
      _toggleCurrentItem();
    }
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
    } else if (_selectedIndex == 3) {
      configManager.writeGlobalSettings(
        settings.copyWith(showThinking: !settings.showThinking),
      );
      setState(() {});
    } else if (_selectedIndex == 4) {
      final newValue = !settings.soundNotificationsEnabled;
      configManager.writeGlobalSettings(
        settings.copyWith(soundNotificationsEnabled: newValue),
      );
      if (newValue) {
        SoundService.playDirect(
          SoundType.taskComplete,
          customPath: settings.customTaskCompleteSound,
        );
      }
      setState(() {});
    }
  }

  void _saveCompleteSound(String value) {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final path = value.trim().isEmpty ? null : value.trim();
    configManager.writeGlobalSettings(
      settings.copyWith(customTaskCompleteSound: () => path),
    );
    if (path != null) {
      SoundService.playDirect(SoundType.taskComplete, customPath: path);
    }
    setState(() => _editingIndex = null);
  }

  void _saveAttentionSound(String value) {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final path = value.trim().isEmpty ? null : value.trim();
    configManager.writeGlobalSettings(
      settings.copyWith(customAttentionNeededSound: () => path),
    );
    if (path != null) {
      SoundService.playDirect(SoundType.attentionNeeded, customPath: path);
    }
    setState(() => _editingIndex = null);
  }

  @override
  Component build(BuildContext context) {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final ideModeEnabled = settings.ideModeEnabled;
    final gitSidebarEnabled = settings.gitSidebarEnabled;
    final streamingEnabled = settings.enableStreaming;
    final showThinking = settings.showThinking;
    final soundEnabled = settings.soundNotificationsEnabled;

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
                    isSelected:
                        component.focused &&
                        _selectedIndex == 0 &&
                        _editingIndex == null,
                    onTap: () {
                      setState(() => _selectedIndex = 0);
                      _activateCurrentItem();
                    },
                  ),
                  SettingsToggleItem(
                    label: 'Git Sidebar',
                    description: 'Show git status',
                    value: gitSidebarEnabled,
                    isSelected:
                        component.focused &&
                        _selectedIndex == 1 &&
                        _editingIndex == null,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                      _activateCurrentItem();
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
                  SettingsToggleItem(
                    label: 'Show Thinking',
                    description: 'Display model thinking blocks',
                    value: showThinking,
                    isSelected:
                        component.focused &&
                        _selectedIndex == 3 &&
                        _editingIndex == null,
                    onTap: () {
                      setState(() => _selectedIndex = 3);
                      _activateCurrentItem();
                    },
                  ),
                  SettingsToggleItem(
                    label: 'Sound Notifications',
                    description: 'Alert when attention needed',
                    value: soundEnabled,
                    isSelected:
                        component.focused &&
                        _selectedIndex == 4 &&
                        _editingIndex == null,
                    onTap: () {
                      setState(() => _selectedIndex = 4);
                      _activateCurrentItem();
                    },
                  ),
                  SettingsTextInput(
                    label: 'Complete Sound',
                    description: 'Custom audio file for task complete',
                    value: settings.customTaskCompleteSound ?? 'default',
                    isSelected:
                        component.focused &&
                        _selectedIndex == 5 &&
                        _editingIndex == null,
                    isEditing: _editingIndex == 5,
                    controller: _completeSoundController,
                    onTap: () {
                      setState(() => _selectedIndex = 5);
                      _activateCurrentItem();
                    },
                    onSubmitted: _saveCompleteSound,
                  ),
                  SettingsTextInput(
                    label: 'Attention Sound',
                    description: 'Custom audio file for attention needed',
                    value: settings.customAttentionNeededSound ?? 'default',
                    isSelected:
                        component.focused &&
                        _selectedIndex == 6 &&
                        _editingIndex == null,
                    isEditing: _editingIndex == 6,
                    controller: _attentionSoundController,
                    onTap: () {
                      setState(() => _selectedIndex = 6);
                      _activateCurrentItem();
                    },
                    onSubmitted: _saveAttentionSound,
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
