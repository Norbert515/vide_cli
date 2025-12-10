import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:parott/modules/agent_network/pages/networks_overview_page.dart';
import 'package:parott/modules/agent_network/state/console_title_provider.dart';
import 'package:parott/modules/setup/setup_scope.dart';
import 'package:parott/modules/permissions/permission_service.dart';
import 'package:parott/services/parott_config_manager.dart';
import 'package:parott/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:parott/hook_handler.dart';
import 'package:parott/services/sentry_service.dart';

void main(List<String> args) async {
  // Check for --hook flag - run hook handler and exit
  // Hook handler has its own Sentry initialization
  if (args.isNotEmpty && args.first == '--hook') {
    await runHook();
    return;
  }

  // Initialize Sentry and set up nocterm error handler
  await SentryService.init();

  // Initialize global config manager
  ParottConfigManager().initialize();

  // Clean up stale hook files from previous sessions
  await PermissionService.cleanupStaleFiles();

  final container = ProviderContainer();
  await container.read(agentNetworksStateNotifierProvider.notifier).init();

  await runApp(
    ProviderScope(
      parent: container,
      child: ParottApp(container: container),
    ),
  );
}

class ParottApp extends StatelessComponent {
  final ProviderContainer container;

  ParottApp({required this.container});

  @override
  Component build(BuildContext context) {
    return NoctermApp(
      title: context.watch(consoleTitleProvider),
      child: Padding(
        padding: EdgeInsets.all(1),
        child: SetupScope(child: Navigator(home: NetworksOverviewPage())),
      ),
    );
  }
}
