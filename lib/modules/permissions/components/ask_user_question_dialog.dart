import 'package:nocterm/nocterm.dart';
import 'package:vide_core/vide_core.dart';

/// Dialog for displaying structured multiple-choice questions to the user
/// Styled to match Claude Code's native askUserQuestion UI
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

  /// Selected option index for current question (includes "Type something" at the end)
  int _selectedOptionIndex = 0;

  /// For multi-select questions: which options are selected
  final Set<int> _multiSelectedIndices = {};

  /// Collected answers so far (question text -> answer)
  final Map<String, String> _answers = {};

  /// Controller for custom text input
  final _textController = TextEditingController();

  AskUserQuestion get _currentQuestion =>
      component.request.questions[_currentQuestionIndex];
  bool get _isLastQuestion =>
      _currentQuestionIndex >= component.request.questions.length - 1;

  /// Total options including "Type something"
  int get _totalOptions => _currentQuestion.options.length + 1;

  /// Whether the "Type something" option is selected
  bool get _isTypeSomethingSelected =>
      _selectedOptionIndex == _currentQuestion.options.length;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _selectOption() {
    if (_hasResponded) return;

    final question = _currentQuestion;

    if (_isTypeSomethingSelected) {
      // Submit the typed text
      _confirmCustomText();
      return;
    }

    if (question.multiSelect) {
      // Toggle selection
      if (_multiSelectedIndices.contains(_selectedOptionIndex)) {
        setState(() => _multiSelectedIndices.remove(_selectedOptionIndex));
      } else {
        setState(() => _multiSelectedIndices.add(_selectedOptionIndex));
      }
    } else {
      // Single select - record answer and move to next question
      _answers[question.question] =
          question.options[_selectedOptionIndex].label;
      _moveToNextQuestion();
    }
  }

  void _confirmCustomText() {
    if (_hasResponded) return;

    final question = _currentQuestion;
    final text = _textController.text;
    _answers[question.question] = text.isEmpty ? '(empty)' : text;
    setState(() {
      _textController.clear();
    });
    _moveToNextQuestion();
  }

  void _confirmMultiSelect() {
    if (_hasResponded) return;

    final question = _currentQuestion;
    if (!question.multiSelect) return;

    // Build comma-separated list of selected options
    final selectedLabels = _multiSelectedIndices
        .map((i) => question.options[i].label)
        .join(', ');

    _answers[question.question] = selectedLabels.isEmpty
        ? '(none selected)'
        : selectedLabels;
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

  void _goToQuestion(int index) {
    if (index < 0 || index >= component.request.questions.length) return;
    setState(() {
      _currentQuestionIndex = index;
      _selectedOptionIndex = 0;
      _multiSelectedIndices.clear();
    });
  }

  @override
  Component build(BuildContext context) {
    final question = _currentQuestion;
    final options = question.options;
    final totalQuestions = component.request.questions.length;

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        final key = event.logicalKey;
        // When typing in text field, only handle escape and arrow up for navigation
        if (_isTypeSomethingSelected) {
          if (key == LogicalKey.arrowUp) {
            setState(() {
              _selectedOptionIndex = _selectedOptionIndex - 1;
              if (_selectedOptionIndex < 0)
                _selectedOptionIndex = _totalOptions - 1;
            });
            return true;
          } else if (key == LogicalKey.escape) {
            _hasResponded = true;
            component.onSubmit({});
            return true;
          }
          // Let TextField handle other keys
          return false;
        }

        // Normal navigation mode
        if (key == LogicalKey.arrowUp) {
          setState(() {
            _selectedOptionIndex = (_selectedOptionIndex - 1) % _totalOptions;
            if (_selectedOptionIndex < 0)
              _selectedOptionIndex = _totalOptions - 1;
          });
          return true;
        } else if (key == LogicalKey.arrowDown) {
          setState(() {
            _selectedOptionIndex = (_selectedOptionIndex + 1) % _totalOptions;
          });
          return true;
        } else if (key == LogicalKey.arrowLeft && totalQuestions > 1) {
          _goToQuestion(_currentQuestionIndex - 1);
          return true;
        } else if (key == LogicalKey.arrowRight && totalQuestions > 1) {
          _goToQuestion(_currentQuestionIndex + 1);
          return true;
        } else if (key == LogicalKey.tab && totalQuestions > 1) {
          // Tab cycles through questions
          _goToQuestion((_currentQuestionIndex + 1) % totalQuestions);
          return true;
        } else if (key == LogicalKey.enter) {
          if (question.multiSelect && !_isTypeSomethingSelected) {
            _confirmMultiSelect();
          } else {
            _selectOption();
          }
          return true;
        } else if (key == LogicalKey.space &&
            question.multiSelect &&
            !_isTypeSomethingSelected) {
          _selectOption(); // Toggle selection
          return true;
        } else if (key == LogicalKey.escape) {
          // ESC cancels - submit empty answers
          _hasResponded = true;
          component.onSubmit({});
          return true;
        }
        return false;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab navigation header for multiple questions
          if (totalQuestions > 1) ...[
            _buildTabHeader(totalQuestions),
            SizedBox(height: 1),
          ],

          // Question text (bold)
          Text(
            question.question,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 1),

          // Options with numbers
          for (int i = 0; i < options.length; i++)
            _buildOption(i, options[i], question.multiSelect),

          // "Type something" option with inline text field
          _buildTypeSomethingOption(options.length),

          SizedBox(height: 1),

          // Help text
          Text(
            'Enter to select · ${totalQuestions > 1 ? 'Tab/Arrow keys to navigate · ' : ''}Esc to cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Build the tab header showing all questions (matches Claude Code style)
  Component _buildTabHeader(int totalQuestions) {
    return Row(
      children: [
        Text('← ', style: TextStyle(color: Colors.grey)),
        for (int i = 0; i < totalQuestions; i++) ...[
          if (i > 0) Text(' ', style: TextStyle(color: Colors.grey)),
          _buildTabItem(i),
        ],
        Text(' →', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Component _buildTabItem(int index) {
    final question = component.request.questions[index];
    final isActive = index == _currentQuestionIndex;
    final hasAnswer = _answers.containsKey(question.question);
    final label = question.header ?? 'Q${index + 1}';

    // Style: ☒ for unanswered, ✓ for answered, highlighted box for active
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: isActive ? Color.fromARGB(255, 100, 100, 180) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Checkbox indicator
          Text(
            hasAnswer ? '✓ ' : '☐ ',
            style: TextStyle(color: hasAnswer ? Colors.green : Colors.grey),
          ),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Component _buildOption(
    int index,
    AskUserQuestionOption option,
    bool isMultiSelect,
  ) {
    final isSelected = index == _selectedOptionIndex;
    final isChecked = _multiSelectedIndices.contains(index);

    return Container(
      // Add spacing after each option for better readability
      padding: EdgeInsets.only(bottom: option.description.isNotEmpty ? 1 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main option row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection indicator
              Text(
                isSelected ? '› ' : '  ',
                style: TextStyle(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Number
              Text('${index + 1}. ', style: TextStyle(color: Colors.grey)),

              // Checkbox for multi-select
              if (isMultiSelect)
                Text(
                  isChecked ? '[✓] ' : '[ ] ',
                  style: TextStyle(
                    color: isChecked ? Colors.green : Colors.grey,
                    fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                  ),
                ),

              // Option label
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),

          // Description on new line, indented
          if (option.description.isNotEmpty)
            Row(
              children: [
                // Indent to align with label (› + number + space)
                Text('      ', style: TextStyle()),
                Expanded(
                  child: Text(
                    option.description,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Component _buildTypeSomethingOption(int index) {
    final isSelected = _isTypeSomethingSelected;

    return Row(
      children: [
        // Selection indicator
        Text(
          isSelected ? '› ' : '  ',
          style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
        ),

        // Number
        Text('${index + 1}. ', style: TextStyle(color: Colors.grey)),

        // Either text field when selected, or static text
        if (isSelected)
          Expanded(
            child: TextField(
              controller: _textController,
              focused: true,
              placeholder: 'Type something.',
              onSubmitted: (_) => _confirmCustomText(),
            ),
          )
        else
          Text('Type something.', style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}
