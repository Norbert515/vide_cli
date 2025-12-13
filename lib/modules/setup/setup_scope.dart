import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as path;
import '../settings/local_settings_manager.dart';
import 'setup_page.dart';

/// A scope that ensures Vide CLI is properly set up before showing the child.
/// If setup is incomplete, shows SetupPage. Otherwise, shows the child.
class SetupScope extends StatefulComponent {
  final Component child;

  const SetupScope({required this.child, super.key});

  @override
  State<SetupScope> createState() => _SetupScopeState();
}

class _SetupScopeState extends State<SetupScope> {
  bool _isChecking = true;
  bool _isSetup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  /// Find the Vide CLI installation root directory
  String _getVideRoot() {
    // Platform.script points to the main.dart file or compiled executable
    // We need to go up to find the project root where hook.dart lives
    final scriptPath = Platform.script.toFilePath();
    final scriptDir = path.dirname(scriptPath);

    // If running from lib/main.dart, go up one level
    // If running from bin/vide, go up one level
    // Either way, the parent of the script directory should be the project root
    if (path.basename(scriptDir) == 'lib' ||
        path.basename(scriptDir) == 'bin') {
      return path.dirname(scriptDir);
    }

    // Otherwise, assume we're already in the project root
    return scriptDir;
  }

  Future<void> _checkSetup() async {
    try {
      final settingsManager = LocalSettingsManager(
        projectRoot: Directory.current.path,
        parrottRoot: _getVideRoot(),
      );

      final isHookInstalled = await settingsManager.isHookInstalled();

      setState(() {
        _isSetup = isHookInstalled;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isChecking = false;
      });
    }
  }

  void _onSetupComplete() {
    // Re-check setup after installation
    setState(() {
      _isChecking = true;
      _error = null;
    });
    _checkSetup();
  }

  @override
  Component build(BuildContext context) {
    if (_isChecking) {
      return Center(
        child: Text(
          'Checking Vide CLI setup...',
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
              'Error checking setup: $_error',
              style: TextStyle(color: Colors.red),
            ),
            SizedBox(height: 2),
            Text('Press Ctrl+C to exit', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_isSetup) {
      // Setup complete - show the child
      return component.child;
    } else {
      // Setup required - show setup page
      return SetupPage(onSetupComplete: _onSetupComplete);
    }
  }
}
