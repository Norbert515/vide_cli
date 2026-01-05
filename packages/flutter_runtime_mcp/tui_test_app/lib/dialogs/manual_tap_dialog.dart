import 'package:nocterm/nocterm.dart';

/// Dialog for manually testing tap coordinates
class ManualTapDialog extends StatefulComponent {
  const ManualTapDialog({super.key});

  @override
  State<ManualTapDialog> createState() => _ManualTapDialogState();
}

class _ManualTapDialogState extends State<ManualTapDialog> {
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();
  int _focusedField = 0; // 0 = x, 1 = y, 2 = buttons

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
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

        // Enter to submit
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
                  'Manual Tap Test',
                  style: TextStyle(
                    color: Colors.brightGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 1),

              // Info text
              const Text(
                'Enter pixel coordinates to test tap functionality:',
                style: TextStyle(color: Colors.cyan),
              ),
              const SizedBox(height: 1),

              // X coordinate field
              const Text(
                'X Coordinate:',
                style: TextStyle(
                  color: Colors.yellow,
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
                  controller: _xController,
                  placeholder: 'e.g., 200',
                  style: const TextStyle(color: Colors.white),
                  focused: _focusedField == 0,
                ),
              ),
              const SizedBox(height: 1),

              // Y coordinate field
              const Text(
                'Y Coordinate:',
                style: TextStyle(
                  color: Colors.yellow,
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
                  controller: _yController,
                  placeholder: 'e.g., 300',
                  style: const TextStyle(color: Colors.white),
                  focused: _focusedField == 1,
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
    final xText = _xController.text.trim();
    final yText = _yController.text.trim();

    if (xText.isEmpty || yText.isEmpty) {
      return;
    }

    final x = double.tryParse(xText);
    final y = double.tryParse(yText);

    if (x == null || y == null) {
      return;
    }

    Navigator.of(context).pop({'x': x, 'y': y});
  }
}
