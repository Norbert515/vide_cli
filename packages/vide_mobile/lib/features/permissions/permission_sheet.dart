import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/glass_surface.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/vide_colors.dart';
import '../../domain/models/models.dart';

/// Bottom sheet for permission requests.
class PermissionSheet extends StatefulWidget {
  final PermissionRequest request;
  final void Function({required bool remember}) onAllow;
  final VoidCallback onDeny;

  const PermissionSheet({
    super.key,
    required this.request,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  State<PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends State<PermissionSheet> {
  bool _alwaysAllow = false;
  bool _inputExpanded = false;

  void _handleAllow() {
    widget.onAllow(remember: _alwaysAllow);
  }

  void _handleDeny() {
    widget.onDeny();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return GlassSurface.heavy(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(VideRadius.glass)),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: videColors.warningContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.security_outlined,
                          size: 24,
                          color: videColors.warning,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Permission Request',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Tool info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: videColors.accentSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.build_outlined,
                              size: 18,
                              color: videColors.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.request.toolName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
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
                  // Collapsible tool input
                  InkWell(
                    onTap: () =>
                        setState(() => _inputExpanded = !_inputExpanded),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Tool Input',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const Spacer(),
                              Icon(
                                _inputExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: videColors.textSecondary,
                              ),
                            ],
                          ),
                          if (_inputExpanded) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: SingleChildScrollView(
                                child: Text(
                                  const JsonEncoder.withIndent('  ')
                                      .convert(widget.request.toolInput),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Always allow checkbox
                  CheckboxListTile(
                    value: _alwaysAllow,
                    onChanged: (value) =>
                        setState(() => _alwaysAllow = value ?? false),
                    title: const Text('Always allow this tool'),
                    subtitle: const Text('Add to auto-approve list'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  const SizedBox(height: 16),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleDeny,
                          icon: const Icon(Icons.close),
                          label: const Text('Deny'),
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
                          onPressed: _handleAllow,
                          icon: const Icon(Icons.check),
                          label: const Text('Allow'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ),
                    ],
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
