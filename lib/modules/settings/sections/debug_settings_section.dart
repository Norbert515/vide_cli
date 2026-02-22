import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/vide_core.dart'
    show VideLogger, videConfigManagerProvider;
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/main.dart' show filePreviewPathProvider;
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';
import 'package:vide_cli/modules/settings/components/settings_card.dart';
import 'package:vide_cli/modules/settings/components/settings_toggle.dart';
import 'package:vide_cli/theme/theme.dart';

/// Debug settings: Codex backend toggle, session logs viewer.
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

  // [0] = Codex backend, [1] = Session logs
  static const int _totalItems = 2;

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
      _activateCurrentItem();
      return true;
    }

    return false;
  }

  void _activateCurrentItem() {
    switch (_selectedIndex) {
      case 0:
        _toggleCodexBackend();
      case 1:
        _openSessionLogs();
    }
  }

  void _toggleCodexBackend() {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    configManager.writeGlobalSettings(
      settings.copyWith(useCodexBackend: !settings.useCodexBackend),
    );
    setState(() {});
  }

  void _openSessionLogs() {
    final session = context.read(currentVideSessionProvider);
    final sessionId = session?.id;
    if (sessionId == null) return;
    final logPath = VideLogger.instance.sessionLogPath(sessionId);
    context.read(filePreviewPathProvider.notifier).state = logPath;
  }

  @override
  Component build(BuildContext context) {
    final configManager = context.read(videConfigManagerProvider);
    final settings = configManager.readGlobalSettings();
    final useCodexBackend = settings.useCodexBackend;

    final session = context.watch(currentVideSessionProvider);
    final sessionId = session?.id;
    final logPath = sessionId != null
        ? VideLogger.instance.sessionLogPath(sessionId)
        : null;

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
                      _toggleCodexBackend();
                    },
                  ),
                  _SessionLogsItem(
                    logPath: logPath,
                    isSelected: component.focused && _selectedIndex == 1,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                      _openSessionLogs();
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

class _SessionLogsItem extends StatelessComponent {
  final String? logPath;
  final bool isSelected;
  final VoidCallback onTap;

  const _SessionLogsItem({
    required this.logPath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? theme.base.primary.withOpacity(0.2) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Logs',
                    style: TextStyle(
                      color: theme.base.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    logPath ?? 'No active session',
                    style: TextStyle(
                      color: theme.base.onSurface.withOpacity(
                        TextOpacity.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\u2192',
              style: TextStyle(
                color: isSelected ? theme.base.primary : theme.base.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
