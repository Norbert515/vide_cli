import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as path;
import '../settings/local_settings_manager.dart';

class SetupPage extends StatefulComponent {
  final VoidCallback onSetupComplete;

  const SetupPage({required this.onSetupComplete, super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  bool _isInstalling = false;
  String? _error;
  SettingsDiff? _diff;

  @override
  void initState() {
    super.initState();
    _loadDiff();
  }

  /// Find the Vide CLI installation root directory
  String _getParrottRoot() {
    final scriptPath = Platform.script.toFilePath();
    final scriptDir = path.dirname(scriptPath);

    if (path.basename(scriptDir) == 'lib' ||
        path.basename(scriptDir) == 'bin') {
      return path.dirname(scriptDir);
    }

    return scriptDir;
  }

  Future<void> _loadDiff() async {
    final settingsManager = LocalSettingsManager(
      projectRoot: Directory.current.path,
      parrottRoot: _getParrottRoot(),
    );

    try {
      final diff = await settingsManager.generateInstallDiff();
      setState(() {
        _diff = diff;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to generate setup plan: $e';
      });
    }
  }

  Future<void> _installHook() async {
    setState(() {
      _isInstalling = true;
      _error = null;
    });

    final settingsManager = LocalSettingsManager(
      projectRoot: Directory.current.path,
      parrottRoot: _getParrottRoot(),
    );

    try {
      await settingsManager.installHook();
      // Wait a moment to ensure file is written
      await Future.delayed(Duration(milliseconds: 100));
      component.onSetupComplete();
    } catch (e) {
      setState(() {
        _isInstalling = false;
        _error = 'Installation failed: $e';
      });
    }
  }

  @override
  Component build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 1, horizontal: 2),
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'Vide CLI Setup',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SizedBox(height: 2),

          // Explanation
          Text(
            'Vide CLI needs to install a permission hook in your Claude Code settings.',
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 1),
          Text(
            'This hook will intercept tool calls and allow you to approve/deny them.',
            style: TextStyle(color: Colors.grey),
          ),

          SizedBox(height: 2),

          // Show diff if loaded
          if (_diff != null) ...[
            Container(
              padding: EdgeInsets.all(1),
              decoration: BoxDecoration(
                border: BoxBorder.all(color: Colors.grey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Changes to be made:',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    _diff!.toPrettyString(),
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
            SizedBox(height: 2),
          ],

          // Error display
          if (_error != null) ...[
            Container(
              padding: EdgeInsets.all(1),
              decoration: BoxDecoration(color: Color(0xFF331111)),
              child: Text(_error!, style: TextStyle(color: Colors.red)),
            ),
            SizedBox(height: 2),
          ],

          // Loading state
          if (_isInstalling) ...[
            Text('Installing hook...', style: TextStyle(color: Colors.yellow)),
          ],

          // Action buttons
          if (!_isInstalling && _diff != null)
            KeyboardListener(
              onKeyEvent: (key) {
                if (key == LogicalKey.enter || key == LogicalKey.keyY) {
                  _installHook();
                  return true;
                } else if (key == LogicalKey.keyN || key == LogicalKey.escape) {
                  exit(0);
                  return true;
                }
                return false;
              },
              autofocus: true,
              child: Row(
                children: [
                  Text(
                    '[Enter/Y] Install & Continue',
                    style: TextStyle(color: Colors.green),
                  ),
                  SizedBox(width: 4),
                  Text('[N/Esc] Exit', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
