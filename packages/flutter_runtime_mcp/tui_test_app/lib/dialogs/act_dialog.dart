import 'package:nocterm/nocterm.dart';

/// Dialog for performing an action on a Flutter UI element
class ActDialog extends StatefulComponent {
  const ActDialog({super.key});

  @override
  State<ActDialog> createState() => _ActDialogState();
}

class _ActDialogState extends State<ActDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  int _focusedField = 0; // 0 = description, 1 = buttons

  @override
  void dispose() {
    _descriptionController.dispose();
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
            _focusedField = (_focusedField + 1) % 2;
          });
          return true;
        }

        // Escape to cancel
        if (event.logicalKey == LogicalKey.escape) {
          Navigator.of(context).pop();
          return true;
        }

        // Enter to submit
        if (event.logicalKey == LogicalKey.enter) {
          _handleSubmit(context);
          return true;
        }

        // Let other keys pass through to the focused TextField
        if (_focusedField == 0) {
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
                  'Perform Action on UI Element',
                  style: TextStyle(
                    color: Colors.brightGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 1),

              // Info text
              const Text(
                'Describe the UI element to interact with (e.g., "login button", "submit form"):',
                style: TextStyle(color: Colors.cyan),
              ),
              const SizedBox(height: 1),

              // Description field
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
                  controller: _descriptionController,
                  placeholder: 'e.g., "increment button"',
                  style: const TextStyle(color: Colors.white),
                  focused: _focusedField == 0,
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
                        color: _focusedField == 1
                            ? Colors.green
                            : const Color.fromRGB(0, 60, 0),
                        border: BoxBorder.all(
                          color: _focusedField == 1
                              ? Colors.brightGreen
                              : Colors.green,
                        ),
                      ),
                      child: const Text(
                        '[ Tap ]',
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
                  '[Enter] Tap • [Tab] Switch fields • [Esc] Cancel',
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
    final description = _descriptionController.text.trim();

    if (description.isEmpty) {
      // Could show error, but for now just ignore
      return;
    }

    Navigator.of(context).pop({'action': 'tap', 'description': description});
  }
}
