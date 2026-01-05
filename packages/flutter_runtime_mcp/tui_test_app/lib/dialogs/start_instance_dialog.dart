import 'dart:io';
import 'package:nocterm/nocterm.dart';

/// Dialog for starting a new Flutter instance
class StartInstanceDialog extends StatefulComponent {
  const StartInstanceDialog({super.key});

  @override
  State<StartInstanceDialog> createState() => _StartInstanceDialogState();
}

class _StartInstanceDialogState extends State<StartInstanceDialog> {
  final TextEditingController _commandController = TextEditingController(
    text: 'flutter run -d macos',
  );
  final TextEditingController _workingDirController = TextEditingController(
    text: Directory.current.path,
  );
  int _focusedField = 0; // 0 = command, 1 = working dir, 2 = buttons

  @override
  void dispose() {
    _commandController.dispose();
    _workingDirController.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        // Tab to switch fields
        if (event.logicalKey == LogicalKey.tab) {
          setState(() {
            _focusedField = (_focusedField + 1) % 3;
          });
          return true;
        }

        // Escape to cancel
        if (event.logicalKey == LogicalKey.escape) {
          Navigator.of(context).pop();
          return true;
        }

        // Enter to submit from any field
        if (event.logicalKey == LogicalKey.enter) {
          _handleSubmit(context);
          return true;
        }

        // Let other keys pass through to the focused TextField
        if (_focusedField == 0 || _focusedField == 1) {
          return false; // Don't consume the event, let TextField handle it
        }

        return false;
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(color: Color.fromRGB(20, 20, 40)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Center(
                child: Text(
                  'Start New Flutter Instance',
                  style: TextStyle(
                    color: Colors.brightGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 1),

              // Command field
              const Text(
                'Command:',
                style: TextStyle(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: BoxBorder.all(
                    color: _focusedField == 0 ? Colors.brightCyan : Colors.gray,
                    style: _focusedField == 0
                        ? BoxBorderStyle.double
                        : BoxBorderStyle.solid,
                  ),
                  color: const Color.fromRGB(10, 10, 30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: TextField(
                  controller: _commandController,
                  placeholder: 'flutter run -d macos',
                  style: const TextStyle(color: Colors.white),
                  focused: _focusedField == 0,
                ),
              ),
              const SizedBox(height: 1),

              // Working directory field
              const Text(
                'Working Directory:',
                style: TextStyle(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: BoxBorder.all(
                    color: _focusedField == 1 ? Colors.brightCyan : Colors.gray,
                    style: _focusedField == 1
                        ? BoxBorderStyle.double
                        : BoxBorderStyle.solid,
                  ),
                  color: const Color.fromRGB(10, 10, 30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: TextField(
                  controller: _workingDirController,
                  style: const TextStyle(color: Colors.white),
                  focused: _focusedField == 1,
                  maxLines: 1,
                  onSubmitted: (_) => _handleSubmit(context),
                ),
              ),
              const SizedBox(height: 1),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _handleSubmit(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _focusedField == 2
                            ? Colors.green
                            : const Color.fromRGB(0, 60, 0),
                        border: BoxBorder.all(
                          color: _focusedField == 2
                              ? Colors.brightGreen
                              : Colors.green,
                        ),
                      ),
                      child: const Text(
                        '[ Start ]',
                        style: TextStyle(
                          color: Colors.brightWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromRGB(60, 0, 0),
                        border: BoxBorder.all(color: Colors.red),
                      ),
                      child: const Text(
                        '[ Cancel ]',
                        style: TextStyle(color: Colors.brightWhite),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),

              // Help text
              const Center(
                child: Text(
                  '[Enter] Start • [Tab] Switch fields • [Esc] Cancel',
                  style: TextStyle(
                    color: Colors.gray,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSubmit(BuildContext context) {
    final command = _commandController.text.trim();
    final workingDir = _workingDirController.text.trim();

    if (command.isEmpty) {
      // Could show error, but for now just ignore
      return;
    }

    Navigator.of(context).pop({
      'command': command,
      'workingDir': workingDir.isEmpty ? Directory.current.path : workingDir,
    });
  }
}
