import 'package:flutter/material.dart';
import 'package:vide_client/vide_client.dart';

import '../../core/theme/glass_surface.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/vide_colors.dart';

/// Bottom sheet for AskUserQuestion requests.
///
/// Shows one question at a time (with tabs if multiple). Each question
/// displays its options for single or multi-select. An "Other" option
/// with a text field is always available for custom input.
class AskUserQuestionSheet extends StatefulWidget {
  final AskUserQuestionEvent request;
  final void Function(Map<String, String> answers) onSubmit;

  const AskUserQuestionSheet({
    super.key,
    required this.request,
    required this.onSubmit,
  });

  @override
  State<AskUserQuestionSheet> createState() => _AskUserQuestionSheetState();
}

class _AskUserQuestionSheetState extends State<AskUserQuestionSheet> {
  late int _currentQuestionIndex;

  /// For single-select: index of selected option (null = none, -1 = "Other").
  /// For multi-select: tracked via _multiSelections.
  final Map<int, int?> _singleSelections = {};

  /// For multi-select: set of selected option indices per question.
  final Map<int, Set<int>> _multiSelections = {};

  /// Custom text input per question (for "Other" option).
  final Map<int, TextEditingController> _otherControllers = {};

  /// Whether "Other" is active per question.
  final Map<int, bool> _otherActive = {};

  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _currentQuestionIndex = 0;
    for (var i = 0; i < widget.request.questions.length; i++) {
      _otherControllers[i] = TextEditingController();
      _otherActive[i] = false;
      if (widget.request.questions[i].multiSelect) {
        _multiSelections[i] = {};
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _otherControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isQuestionAnswered(int questionIndex) {
    final question = widget.request.questions[questionIndex];
    if (_otherActive[questionIndex] == true) {
      return _otherControllers[questionIndex]!.text.trim().isNotEmpty;
    }
    if (question.multiSelect) {
      return (_multiSelections[questionIndex]?.isNotEmpty ?? false);
    }
    return _singleSelections[questionIndex] != null;
  }

  bool get _allQuestionsAnswered {
    for (var i = 0; i < widget.request.questions.length; i++) {
      if (!_isQuestionAnswered(i)) return false;
    }
    return true;
  }

  String _getAnswer(int questionIndex) {
    if (_otherActive[questionIndex] == true) {
      return _otherControllers[questionIndex]!.text.trim();
    }
    final question = widget.request.questions[questionIndex];
    if (question.multiSelect) {
      final indices = _multiSelections[questionIndex] ?? {};
      return indices.map((i) => question.options[i].label).join(', ');
    }
    final selectedIndex = _singleSelections[questionIndex];
    if (selectedIndex != null && selectedIndex >= 0) {
      return question.options[selectedIndex].label;
    }
    return '';
  }

  void _handleSubmit() {
    if (_hasSubmitted || !_allQuestionsAnswered) return;
    _hasSubmitted = true;

    final answers = <String, String>{};
    for (var i = 0; i < widget.request.questions.length; i++) {
      answers[widget.request.questions[i].question] = _getAnswer(i);
    }
    widget.onSubmit(answers);
  }

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final questions = widget.request.questions;
    final hasMultipleQuestions = questions.length > 1;
    final screenHeight = MediaQuery.of(context).size.height;

    return GlassSurface.heavy(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(VideRadius.glass)),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        size: 20,
                        color: videColors.info,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Question',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (hasMultipleQuestions) ...[
                        const Spacer(),
                        Text(
                          '${_currentQuestionIndex + 1} of ${questions.length}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: videColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  if (widget.request.agentName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'from ${widget.request.agentName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: videColors.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            // Question tabs (if multiple)
            if (hasMultipleQuestions) ...[
              const SizedBox(height: 12),
              _QuestionTabs(
                questions: questions,
                currentIndex: _currentQuestionIndex,
                isAnswered: _isQuestionAnswered,
                onTap: (index) =>
                    setState(() => _currentQuestionIndex = index),
              ),
            ],
            const SizedBox(height: 16),
            // Current question content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _QuestionContent(
                  question: questions[_currentQuestionIndex],
                  questionIndex: _currentQuestionIndex,
                  singleSelection: _singleSelections[_currentQuestionIndex],
                  multiSelections:
                      _multiSelections[_currentQuestionIndex] ?? {},
                  otherActive: _otherActive[_currentQuestionIndex] ?? false,
                  otherController:
                      _otherControllers[_currentQuestionIndex]!,
                  onSingleSelect: (optionIndex) {
                    setState(() {
                      _singleSelections[_currentQuestionIndex] = optionIndex;
                      _otherActive[_currentQuestionIndex] = false;
                    });
                  },
                  onMultiToggle: (optionIndex) {
                    setState(() {
                      final set = _multiSelections[_currentQuestionIndex] ??= {};
                      if (set.contains(optionIndex)) {
                        set.remove(optionIndex);
                      } else {
                        set.add(optionIndex);
                      }
                      _otherActive[_currentQuestionIndex] = false;
                    });
                  },
                  onOtherTap: () {
                    setState(() {
                      _otherActive[_currentQuestionIndex] = true;
                      _singleSelections.remove(_currentQuestionIndex);
                      _multiSelections[_currentQuestionIndex]?.clear();
                    });
                  },
                  onOtherChanged: () => setState(() {}),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Navigation / Submit
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildActions(hasMultipleQuestions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(bool hasMultipleQuestions) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final isLastQuestion =
        _currentQuestionIndex == widget.request.questions.length - 1;

    if (hasMultipleQuestions && !isLastQuestion) {
      return Row(
        children: [
          if (_currentQuestionIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentQuestionIndex--),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentQuestionIndex > 0) const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: _isQuestionAnswered(_currentQuestionIndex)
                  ? () => setState(() => _currentQuestionIndex++)
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Next'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (hasMultipleQuestions && _currentQuestionIndex > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentQuestionIndex--),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: FilledButton.icon(
            onPressed: _allQuestionsAnswered ? _handleSubmit : null,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Submit'),
            style: FilledButton.styleFrom(
              backgroundColor: videColors.accent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tab indicators for multiple questions.
class _QuestionTabs extends StatelessWidget {
  final List<AskUserQuestionData> questions;
  final int currentIndex;
  final bool Function(int) isAnswered;
  final ValueChanged<int> onTap;

  const _QuestionTabs({
    required this.questions,
    required this.currentIndex,
    required this.isAnswered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: questions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isActive = index == currentIndex;
          final answered = isAnswered(index);
          final label = questions[index].header ?? 'Q${index + 1}';

          return GestureDetector(
            onTap: () => onTap(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? videColors.accent.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: VideRadius.mdAll,
                border: Border.all(
                  color: isActive
                      ? videColors.accent
                      : colorScheme.outlineVariant,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (answered) ...[
                    Icon(Icons.check_circle,
                        size: 14, color: videColors.success),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? videColors.accent
                          : videColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Content for a single question: question text + option list.
class _QuestionContent extends StatelessWidget {
  final AskUserQuestionData question;
  final int questionIndex;
  final int? singleSelection;
  final Set<int> multiSelections;
  final bool otherActive;
  final TextEditingController otherController;
  final ValueChanged<int> onSingleSelect;
  final ValueChanged<int> onMultiToggle;
  final VoidCallback onOtherTap;
  final VoidCallback onOtherChanged;

  const _QuestionContent({
    required this.question,
    required this.questionIndex,
    required this.singleSelection,
    required this.multiSelections,
    required this.otherActive,
    required this.otherController,
    required this.onSingleSelect,
    required this.onMultiToggle,
    required this.onOtherTap,
    required this.onOtherChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question text
        Text(
          question.question,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 16),
        // Options
        for (var i = 0; i < question.options.length; i++) ...[
          _OptionTile(
            option: question.options[i],
            isMultiSelect: question.multiSelect,
            isSelected: question.multiSelect
                ? multiSelections.contains(i)
                : singleSelection == i,
            onTap: () {
              if (question.multiSelect) {
                onMultiToggle(i);
              } else {
                onSingleSelect(i);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
        // "Other" option
        _OtherOptionTile(
          isActive: otherActive,
          controller: otherController,
          onTap: onOtherTap,
          onChanged: onOtherChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// A single selectable option tile.
class _OptionTile extends StatelessWidget {
  final AskUserQuestionOptionData option;
  final bool isMultiSelect;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isMultiSelect,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? videColors.accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: VideRadius.mdAll,
          border: Border.all(
            color: isSelected ? videColors.accent : colorScheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Selection indicator
            if (isMultiSelect)
              Icon(
                isSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: isSelected ? videColors.accent : videColors.textTertiary,
              )
            else
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: isSelected ? videColors.accent : videColors.textTertiary,
              ),
            const SizedBox(width: 12),
            // Label + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (option.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: videColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Other" option with text input.
class _OtherOptionTile extends StatelessWidget {
  final bool isActive;
  final TextEditingController controller;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  const _OtherOptionTile({
    required this.isActive,
    required this.controller,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? videColors.accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: VideRadius.mdAll,
          border: Border.all(
            color: isActive ? videColors.accent : colorScheme.outlineVariant,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isActive ? videColors.accent : videColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isActive
                  ? TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Type your answer...',
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (_) => onChanged(),
                    )
                  : Text(
                      'Other',
                      style: TextStyle(
                        fontSize: 14,
                        color: videColors.textSecondary,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
