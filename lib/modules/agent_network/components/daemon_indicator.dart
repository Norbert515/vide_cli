import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/main.dart' show daemonModeEnabledProvider;
import 'package:vide_cli/modules/remote/daemon_connection_service.dart';
import 'package:vide_cli/theme/theme.dart';

class DaemonIndicator extends StatefulComponent {
  final bool focused;
  final void Function()? onDownEdge;
  final void Function()? onEnter;

  const DaemonIndicator({
    this.focused = false,
    this.onDownEdge,
    this.onEnter,
    super.key,
  });

  @override
  State<DaemonIndicator> createState() => _DaemonIndicatorState();
}

class _DaemonIndicatorState extends State<DaemonIndicator> {
  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.arrowDown ||
        event.logicalKey == LogicalKey.escape) {
      component.onDownEdge?.call();
      return true;
    } else if (event.logicalKey == LogicalKey.enter) {
      component.onEnter?.call();
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final daemonState = context.watch(daemonConnectionProvider);
    final daemonEnabled = context.watch(daemonModeEnabledProvider);
    if (!daemonEnabled) return const SizedBox.shrink();

    return Focusable(
      focused: component.focused,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (daemonState.isConnecting)
              Text(
                '⟳ Connecting to daemon...',
                style: TextStyle(
                  color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
                ),
              )
            else if (daemonState.error != null)
              Text(
                '⚠ ${daemonState.error}',
                style: TextStyle(color: theme.base.error),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('◉ ', style: TextStyle(color: theme.status.idle)),
                  if (component.focused)
                    Text(
                      ' daemon ${daemonState.host}:${daemonState.port} ',
                      style: TextStyle(
                        color: theme.base.background,
                        backgroundColor: theme.base.primary,
                      ),
                    )
                  else ...[
                    Text(
                      'daemon ',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.secondary,
                        ),
                      ),
                    ),
                    Text(
                      '${daemonState.host}:${daemonState.port}',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.tertiary,
                        ),
                      ),
                    ),
                  ],
                  if (!component.focused)
                    Text(
                      '  ↑',
                      style: TextStyle(
                        color: theme.base.onSurface.withOpacity(
                          TextOpacity.disabled,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
