import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';
import 'welcome_page.dart';

/// A scope that shows the welcome page on first run of Vide CLI.
/// If first run is complete, shows the child directly.
class WelcomeScope extends StatefulComponent {
  final Component child;

  const WelcomeScope({required this.child, super.key});

  @override
  State<WelcomeScope> createState() => _WelcomeScopeState();
}

class _WelcomeScopeState extends State<WelcomeScope> {
  bool _isChecking = true;
  bool _isFirstRun = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    try {
      // Dev mode: VIDE_FORCE_WELCOME=1 forces welcome screen to show
      final forceWelcome = Platform.environment['VIDE_FORCE_WELCOME'] == '1';
      if (forceWelcome) {
        setState(() {
          _isFirstRun = true;
          _isChecking = false;
        });
        return;
      }

      // Check global first-run status
      final homeDir =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (homeDir == null) {
        setState(() {
          _error = 'Could not determine home directory';
          _isChecking = false;
        });
        return;
      }

      final configManager = VideConfigManager(
        configRoot: path.join(homeDir, '.vide'),
      );
      final isFirstRun = configManager.isFirstRun();

      setState(() {
        _isFirstRun = isFirstRun;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isChecking = false;
      });
    }
  }

  Future<void> _onWelcomeComplete(String? themeId) async {
    try {
      final homeDir =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (homeDir == null) {
        setState(() {
          _error = 'Could not determine home directory';
        });
        return;
      }

      final configManager = VideConfigManager(
        configRoot: path.join(homeDir, '.vide'),
      );
      configManager.markFirstRunComplete();
      configManager.setTheme(themeId);

      // IMPORTANT: Set _isFirstRun = false BEFORE updating theme provider
      // to prevent WelcomePage from being recreated with fresh state
      // when the provider triggers a rebuild
      setState(() {
        _isFirstRun = false;
      });

      // Update the theme provider so the app uses the new theme
      context.read(themeSettingProvider.notifier).state = themeId;
    } catch (e) {
      setState(() {
        _error = 'Failed to save settings: $e';
      });
    }
  }

  @override
  Component build(BuildContext context) {
    if (_isChecking) {
      return Center(
        child: Text('Loading...', style: TextStyle(color: Colors.grey)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: TextStyle(color: Colors.red)),
            SizedBox(height: 2),
            Text('Press Ctrl+C to exit', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_isFirstRun) {
      return WelcomePage(onComplete: _onWelcomeComplete);
    }

    return component.child;
  }
}
