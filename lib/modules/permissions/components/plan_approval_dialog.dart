import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/modules/permissions/permission_scope.dart';

/// Dialog for displaying a plan and allowing the user to accept or reject it.
///
/// Shown when an agent calls `ExitPlanMode`. Displays the plan content in a
/// scrollable area and offers accept/reject options.
class PlanApprovalDialog extends StatefulComponent {
  final PlanApprovalUIRequest request;
  final Function(String action, String? feedback) onResponse;

  const PlanApprovalDialog({
    required this.request,
    required this.onResponse,
    super.key,
  });

  @override
  State<PlanApprovalDialog> createState() => _PlanApprovalDialogState();
}

class _PlanApprovalDialogState extends State<PlanApprovalDialog> {
  bool _hasResponded = false;

  /// 0 = Accept, 1 = Reject (with feedback text field)
  int _selectedOptionIndex = 0;

  /// Controller for rejection feedback text input
  final _textController = TextEditingController();

  /// Scroll controller for the plan content
  final _scrollController = ScrollController();

  /// Whether the reject option is selected
  bool get _isRejectSelected => _selectedOptionIndex == 1;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _accept() {
    if (_hasResponded) return;
    _hasResponded = true;
    component.onResponse('accept', null);
  }

  void _reject() {
    if (_hasResponded) return;
    _hasResponded = true;
    final feedback = _textController.text;
    component.onResponse('reject', feedback.isEmpty ? null : feedback);
  }

  @override
  Component build(BuildContext context) {
    final planLines = component.request.planContent.split('\n');

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        final key = event.logicalKey;

        // When typing in reject text field, only handle arrow up and escape
        if (_isRejectSelected) {
          if (key == LogicalKey.arrowUp) {
            setState(() => _selectedOptionIndex = 0);
            return true;
          } else if (key == LogicalKey.escape) {
            _reject();
            return true;
          }
          // Let TextField handle other keys
          return false;
        }

        // Option navigation with arrow keys
        if (key == LogicalKey.arrowDown) {
          if (_selectedOptionIndex == 0) {
            setState(() => _selectedOptionIndex = 1);
            return true;
          }
          // Already on reject, scroll plan content
          _scrollController.scrollDown();
          return true;
        } else if (key == LogicalKey.arrowUp) {
          _scrollController.scrollUp();
          return true;
        } else if (key == LogicalKey.pageUp) {
          _scrollController.pageUp();
          return true;
        } else if (key == LogicalKey.pageDown) {
          _scrollController.pageDown();
          return true;
        }

        // Option selection
        if (key == LogicalKey.enter) {
          if (_selectedOptionIndex == 0) {
            _accept();
          } else {
            _reject();
          }
          return true;
        } else if (key == LogicalKey.tab) {
          // Tab switches between accept/reject
          setState(() {
            _selectedOptionIndex = (_selectedOptionIndex + 1) % 2;
          });
          return true;
        } else if (key == LogicalKey.escape) {
          _reject();
          return true;
        }
        return false;
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          border: BoxBorder.all(color: Colors.grey),
          color: Colors.black,
        ),
        child: Column(
          children: [
            // Title
            Row(
              children: [
                Text(
                  'Plan Review',
                  style: TextStyle(
                    color: Colors.cyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(child: SizedBox()),
                Text(
                  '${planLines.length} lines',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),

            SizedBox(height: 1),

            // Scrollable plan content
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                thumbColor: Colors.cyan,
                trackColor: Color.fromARGB(255, 40, 40, 40),
                child: ListView(
                  lazy: false,
                  controller: _scrollController,
                  children: [MarkdownText(component.request.planContent)],
                ),
              ),
            ),

            Divider(color: Colors.grey),

            // Options
            _buildListItem(index: 0, label: 'Accept plan', isAccept: true),
            _buildRejectItem(),

            SizedBox(height: 1),

            // Help text
            Text(
              'Enter to select \u00b7 Tab/\u2191\u2193 to switch \u00b7 PgUp/PgDn to scroll \u00b7 Esc to reject',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Component _buildListItem({
    required int index,
    required String label,
    required bool isAccept,
  }) {
    final isSelected = index == _selectedOptionIndex;
    final color = isAccept ? Colors.green : Colors.red;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Text(
            isSelected ? '\u2192 ' : '  ',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Component _buildRejectItem() {
    final isSelected = _isRejectSelected;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: [
          Text(
            isSelected ? '\u2192 ' : '  ',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          if (isSelected) ...[
            Text(
              'Reject: ',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                focused: true,
                maxLines: null,
                placeholder: 'Feedback (optional)',
                onSubmitted: (_) => _reject(),
              ),
            ),
          ] else
            Text('Reject with feedback', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
