import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as path;
import '../settings/local_settings_manager.dart';
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

  /// Find the Vide CLI installation root directory
  String _getVideRoot() {
    final scriptPath = Platform.script.toFilePath();
    final scriptDir = path.dirname(scriptPath);

    if (path.basename(scriptDir) == 'lib' ||
        path.basename(scriptDir) == 'bin') {
      return path.dirname(scriptDir);
    }

    return scriptDir;
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

      final settingsManager = LocalSettingsManager(
        projectRoot: Directory.current.path,
        parrottRoot: _getVideRoot(),
      );

      final isFirstRun = await settingsManager.isFirstRun();

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

  Future<void> _onWelcomeComplete() async {
    try {
      final settingsManager = LocalSettingsManager(
        projectRoot: Directory.current.path,
        parrottRoot: _getVideRoot(),
      );

      await settingsManager.markFirstRunComplete();

      setState(() {
        _isFirstRun = false;
      });
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
        child: Text(
          'Loading...',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_error',
              style: TextStyle(color: Colors.red),
            ),
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
