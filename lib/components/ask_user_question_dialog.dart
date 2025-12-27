import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart';

/// Dialog for displaying structured multiple-choice questions to the user
class AskUserQuestionDialog extends StatefulComponent {
  final AskUserQuestionRequest request;
  final Function(Map<String, String> answers) onSubmit;

  const AskUserQuestionDialog({
    required this.request,
    required this.onSubmit,
    super.key,
  });

  @override
  State<AskUserQuestionDialog> createState() => _AskUserQuestionDialogState();
}

class _AskUserQuestionDialogState extends State<AskUserQuestionDialog> {
  bool _hasResponded = false;

  /// Current question index (for multi-question support)
  int _currentQuestionIndex = 0;

  /// Selected option index for current question
  int _selectedOptionIndex = 0;

  /// For multi-select questions: which options are selected
  final Set<int> _multiSelectedIndices = {};

  /// Collected answers so far (question text -> answer)
  final Map<String, String> _answers = {};

  AskUserQuestion get _currentQuestion => component.request.questions[_currentQuestionIndex];
  bool get _isLastQuestion => _currentQuestionIndex >= component.request.questions.length - 1;

  void _selectOption() {
    if (_hasResponded) return;

    final question = _currentQuestion;

    if (question.multiSelect) {
      // Toggle selection
      if (_multiSelectedIndices.contains(_selectedOptionIndex)) {
        setState(() => _multiSelectedIndices.remove(_selectedOptionIndex));
      } else {
        setState(() => _multiSelectedIndices.add(_selectedOptionIndex));
      }
    } else {
      // Single select - record answer and move to next question
      _answers[question.question] = question.options[_selectedOptionIndex].label;
      _moveToNextQuestion();
    }
  }

  void _confirmMultiSelect() {
    if (_hasResponded) return;

    final question = _currentQuestion;
    if (!question.multiSelect) return;

    // Build comma-separated list of selected options
    final selectedLabels = _multiSelectedIndices
        .map((i) => question.options[i].label)
        .join(', ');

    _answers[question.question] = selectedLabels.isEmpty ? '(none selected)' : selectedLabels;
    _moveToNextQuestion();
  }

  void _moveToNextQuestion() {
    if (_isLastQuestion) {
      // Submit all answers
      _hasResponded = true;
      component.onSubmit(_answers);
    } else {
      // Move to next question
      setState(() {
        _currentQuestionIndex++;
        _selectedOptionIndex = 0;
        _multiSelectedIndices.clear();
      });
    }
  }

  @override
  Component build(BuildContext context) {
    final question = _currentQuestion;
    final options = question.options;
    final totalQuestions = component.request.questions.length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        border: BoxBorder.all(color: Colors.cyan),
        color: Colors.black,
      ),
      child: KeyboardListener(
        onKeyEvent: (key) {
          if (key == LogicalKey.arrowUp) {
            setState(() {
              _selectedOptionIndex = (_selectedOptionIndex - 1) % options.length;
              if (_selectedOptionIndex < 0) _selectedOptionIndex = options.length - 1;
            });
            return true;
          } else if (key == LogicalKey.arrowDown) {
            setState(() {
              _selectedOptionIndex = (_selectedOptionIndex + 1) % options.length;
            });
            return true;
          } else if (key == LogicalKey.enter) {
            if (question.multiSelect) {
              _confirmMultiSelect();
            } else {
              _selectOption();
            }
            return true;
          } else if (key == LogicalKey.space && question.multiSelect) {
            _selectOption(); // Toggle selection
            return true;
          }
          return false;
        },
        autofocus: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with question progress
            Row(
              children: [
                Text(
                  'Question',
                  style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
                ),
                if (totalQuestions > 1) ...[
                  Text(' ', style: TextStyle(color: Colors.cyan)),
                  Text(
                    '(${_currentQuestionIndex + 1}/$totalQuestions)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),

            // Optional header
            if (question.header != null)
              Text(
                question.header!,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),

            // Question text
            Text(
              question.question,
              style: TextStyle(color: Colors.white),
            ),

            // Multi-select hint
            if (question.multiSelect)
              Text(
                '(Space to toggle, Enter to confirm)',
                style: TextStyle(color: Colors.grey),
              ),

            Divider(color: Colors.grey),

            // Options
            for (int i = 0; i < options.length; i++)
              _buildOption(i, options[i], question.multiSelect),
          ],
        ),
      ),
    );
  }

  Component _buildOption(int index, AskUserQuestionOption option, bool isMultiSelect) {
    final isSelected = index == _selectedOptionIndex;
    final isChecked = _multiSelectedIndices.contains(index);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selection indicator
          Text(
            isSelected ? '→ ' : '  ',
            style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
          ),

          // Checkbox for multi-select
          if (isMultiSelect)
            Text(
              isChecked ? '[✓] ' : '[ ] ',
              style: TextStyle(
                color: isChecked ? Colors.green : Colors.grey,
                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
              ),
            ),

          // Option content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected ? Colors.cyan : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (option.description.isNotEmpty)
                  Text(
                    option.description,
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
