import 'package:nocterm/nocterm.dart';
import '../settings/local_settings_manager.dart';

class HookInstallDialog extends StatelessComponent {
  final SettingsDiff diff;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const HookInstallDialog({
    required this.diff,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  @override
  Component build(BuildContext context) {
    return Center(
      child: Container(
        width: 80,
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: BoxBorder.all(color: Colors.blue),
          color: Colors.black,
        ),
        child: KeyboardListener(
          onKeyEvent: (key) {
            if (key == LogicalKey.keyY) {
              onConfirm();
              return true;
            } else if (key == LogicalKey.keyN || key == LogicalKey.escape) {
              onCancel();
              return true;
            }
            return false;
          },
          autofocus: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 1),
                color: Colors.blue,
                child: Center(
                  child: Text(
                    ' Install Permission Hook ',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 1),

              Text(
                'Parott needs to install a hook in Claude Code settings.',
                style: TextStyle(color: Colors.white),
              ),

              SizedBox(height: 2),

              // Show diff
              Container(
                padding: EdgeInsets.all(1),
                decoration: BoxDecoration(color: Colors.grey),
                child: Text(
                  diff.toPrettyString(),
                  style: TextStyle(color: Colors.green),
                ),
              ),

              SizedBox(height: 2),

              // Instructions
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('[Y] Install', style: TextStyle(color: Colors.green)),
                  SizedBox(width: 4),
                  Text('[N] Cancel', style: TextStyle(color: Colors.red)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
