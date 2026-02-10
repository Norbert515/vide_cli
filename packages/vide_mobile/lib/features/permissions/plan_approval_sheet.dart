import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vide_client/vide_client.dart';

import '../../core/theme/glass_surface.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/vide_colors.dart';

/// Bottom sheet for plan approval requests.
///
/// Shows the plan content in a scrollable markdown view with accept/reject
/// options. When rejecting, an optional feedback text field is shown.
class PlanApprovalSheet extends StatefulWidget {
  final PlanApprovalRequestEvent request;
  final void Function(String action, String? feedback) onResponse;

  const PlanApprovalSheet({
    super.key,
    required this.request,
    required this.onResponse,
  });

  @override
  State<PlanApprovalSheet> createState() => _PlanApprovalSheetState();
}

class _PlanApprovalSheetState extends State<PlanApprovalSheet> {
  bool _showRejectFeedback = false;
  bool _hasResponded = false;
  final _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _handleAccept() {
    if (_hasResponded) return;
    _hasResponded = true;
    widget.onResponse('accept', null);
  }

  void _handleRejectTap() {
    setState(() => _showRejectFeedback = true);
  }

  void _handleRejectConfirm() {
    if (_hasResponded) return;
    _hasResponded = true;
    final feedback = _feedbackController.text.trim();
    widget.onResponse('reject', feedback.isEmpty ? null : feedback);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final planLines = widget.request.planContent.split('\n');
    final screenHeight = MediaQuery.of(context).size.height;

    return GlassSurface.heavy(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(VideRadius.glass)),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        // Constrain height to ~70% of screen for the plan content
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
                        Icons.description_outlined,
                        size: 20,
                        color: videColors.info,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Plan Review',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${planLines.length} lines',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: videColors.textSecondary),
                      ),
                    ],
                  ),
                  if (widget.request.agentName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'by ${widget.request.agentName}',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: videColors.textSecondary,
                              ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Scrollable plan content
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: VideRadius.smAll,
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: VideRadius.smAll,
                  child: Markdown(
                    data: widget.request.planContent,
                    shrinkWrap: false,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      h1: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      code: TextStyle(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        fontSize: 12,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: VideRadius.smAll,
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      listBullet: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Reject feedback area (shown after reject tapped)
            if (_showRejectFeedback)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejection feedback (optional)',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: videColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _feedbackController,
                      autofocus: true,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'What should be changed?',
                        border: OutlineInputBorder(
                          borderRadius: VideRadius.smAll,
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      onSubmitted: (_) => _handleRejectConfirm(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _handleRejectConfirm,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: videColors.error,
                          side: BorderSide(color: videColors.error),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Confirm Rejection'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            // Action buttons (hidden when reject feedback is showing)
            if (!_showRejectFeedback)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleRejectTap,
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: videColors.error,
                          side: BorderSide(color: videColors.error),
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _handleAccept,
                        icon: const Icon(Icons.check),
                        label: const Text('Accept'),
                        style: FilledButton.styleFrom(
                          backgroundColor: videColors.success,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
