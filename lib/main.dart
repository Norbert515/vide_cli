import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/pages/networks_overview_page.dart';
import 'package:vide_cli/modules/agent_network/state/console_title_provider.dart';
import 'package:vide_cli/modules/setup/setup_scope.dart';
import 'package:vide_cli/modules/setup/welcome_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/hook_handler.dart';
import 'package:vide_cli/services/sentry_service.dart';

void main(List<String> args, {List<Override> overrides = const []}) async {
  // Check for --hook flag - run hook handler and exit
  // Hook handler has its own Sentry initialization
  if (args.isNotEmpty && args.first == '--hook') {
    await runHook();
    return;
  }

  // Initialize Sentry and set up nocterm error handler
  await SentryService.init();

  // Clean up stale hook files from previous sessions
  await PermissionService.cleanupStaleFiles();

  // Create provider container with overrides from entry point
  final container = ProviderContainer(overrides: overrides);

  // Initialize PostHog analytics
  final configManager = container.read(videConfigManagerProvider);
  await PostHogService.init(configManager);
  PostHogService.appStarted();

  await container.read(agentNetworksStateNotifierProvider.notifier).init();

  await runApp(
    ProviderScope(
      parent: container,
      child: VideApp(container: container),
    ),
  );
}

class VideApp extends StatelessComponent {
  final ProviderContainer container;

  VideApp({required this.container});

  @override
  Component build(BuildContext context) {
    return NoctermApp(
      title: context.watch(consoleTitleProvider),
      child: Padding(
        padding: EdgeInsets.all(1),
        child: WelcomeScope(
          child: SetupScope(child: Navigator(home: NetworksOverviewPage())),
        ),
      ),
    );
  }
}
