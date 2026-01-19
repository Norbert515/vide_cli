import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_cli/modules/agent_network/state/vide_session_providers.dart';

/// Shows the embedded server URL when running.
/// Displayed in the bottom bar alongside the version indicator.
class ServerIndicator extends StatelessComponent {
  const ServerIndicator({super.key});

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final serverState = context.watch(embeddedServerProvider);

    if (!serverState.isRunning) {
      return const SizedBox();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: theme.base.primary.withOpacity(0.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '⚡',
                style: TextStyle(color: theme.base.primary),
              ),
              Text(
                ' ${serverState.url}',
                style: TextStyle(color: theme.base.primary),
              ),
            ],
          ),
        ),
        SizedBox(width: 2),
      ],
    );
  }
}
