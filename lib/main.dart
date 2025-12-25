import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/modules/agent_network/pages/networks_overview_page.dart';
import 'package:vide_cli/modules/agent_network/state/console_title_provider.dart';
import 'package:vide_cli/modules/setup/setup_scope.dart';
import 'package:vide_cli/modules/setup/welcome_scope.dart';
import 'package:vide_cli/modules/permissions/permission_service.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';
import 'package:vide_cli/modules/agent_network/state/agent_networks_state_notifier.dart';
import 'package:vide_cli/services/sentry_service.dart';

/// Provider override for canUseToolCallbackFactory that bridges PermissionService to ClaudeClient.
///
/// This provider creates callbacks that can be passed to ClaudeClient.create() for
/// permission checking via the control protocol.
final _canUseToolCallbackFactoryOverride = canUseToolCallbackFactoryProvider.overrideWith((ref) {
  final permissionService = ref.read(permissionServiceProvider);
  return (String cwd) {
    return (toolName, input, context) async {
      return permissionService.checkToolPermission(
        toolName,
        input,
        context,
        cwd: cwd,
      );
    };
  };
});

void main(List<String> args, {List<Override> overrides = const []}) async {
  // Initialize Sentry and set up nocterm error handler
  await SentryService.init();

  // Create provider container with overrides from entry point and permission callback
  final container = ProviderContainer(overrides: [
    _canUseToolCallbackFactoryOverride,
    ...overrides,
  ]);

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
      // NoctermApp auto-detects terminal brightness and provides TuiTheme
      // VideTheme.auto() reads from TuiTheme to select light/dark vide colors
      child: VideTheme.auto(
        child: Padding(
          padding: EdgeInsets.all(1),
          child: WelcomeScope(
            child: SetupScope(child: Navigator(home: NetworksOverviewPage())),
          ),
        ),
      ),
    );
  }
}
