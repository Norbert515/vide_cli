import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/pages/networks_overview_page.dart';
import 'package:vide_cli/modules/agent_network/state/console_title_provider.dart';
import 'package:vide_cli/modules/setup/setup_scope.dart';
import 'package:vide_cli/modules/setup/welcome_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_cli/services/vide_config_manager.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/hook_handler.dart';
import 'package:vide_cli/services/sentry_service.dart';
import 'package:vide_cli/services/posthog_service.dart';
import 'package:vide_cli/services/vide_settings.dart';

void main(List<String> args) async {
  // Check for --hook flag - run hook handler and exit
  // Hook handler has its own Sentry initialization
  if (args.isNotEmpty && args.first == '--hook') {
    await runHook();
    return;
  }

  // Initialize Sentry and set up nocterm error handler
  await SentryService.init();

  // Initialize global config manager (must be before PostHog)
  VideConfigManager().initialize();

  // Initialize PostHog analytics
  await PostHogService.init();
  PostHogService.appStarted();

  // Load app settings
  await VideSettingsManager.instance.load();

  // Clean up stale hook files from previous sessions
  await PermissionService.cleanupStaleFiles();

  final container = ProviderContainer();
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
