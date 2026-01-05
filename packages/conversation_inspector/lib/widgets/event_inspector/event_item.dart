import 'package:claude_sdk/claude_sdk.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/raw_event.dart';
import 'event_type_badge.dart';
import 'raw_json_viewer.dart';

/// A widget displaying a single event from the conversation.
class EventItem extends StatefulWidget {
  final RawEvent event;
  final bool isSelected;
  final VoidCallback? onTap;

  const EventItem({
    super.key,
    required this.event,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<EventItem> createState() => _EventItemState();
}

class _EventItemState extends State<EventItem> {
  bool _jsonExpanded = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: widget.isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, event),
              const SizedBox(height: 8),
              _buildContent(context, event),
              const SizedBox(height: 8),
              RawJsonViewer(
                json: event.rawJson,
                expanded: _jsonExpanded,
                onToggle: () => setState(() => _jsonExpanded = !_jsonExpanded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RawEvent event) {
    final theme = Theme.of(context);
    final timestamp = event.timestamp;
    final timeStr = timestamp != null
        ? DateFormat('HH:mm:ss.SSS').format(timestamp)
        : null;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Line ${event.lineNumber}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        EventTypeBadges(event: event),
        const Spacer(),
        if (timeStr != null)
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, RawEvent event) {
    final theme = Theme.of(context);
    final response = event.parsedResponse;

    if (response == null) {
      if (event.hasParseError) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Text(
            event.parseError!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        );
      }

      return Text(
        event.getContentPreview(maxLength: 200),
        style: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          fontSize: 13,
        ),
      );
    }

    return _buildParsedContent(context, response);
  }

  Widget _buildParsedContent(BuildContext context, ClaudeResponse response) {
    final theme = Theme.of(context);

    return switch (response) {
      TextResponse r => _buildTextContent(context, r),
      ToolUseResponse r => _buildToolUseContent(context, r),
      ToolResultResponse r => _buildToolResultContent(context, r),
      UserMessageResponse r => _buildUserMessageContent(context, r),
      ErrorResponse r => _buildErrorContent(context, r),
      StatusResponse r => _buildStatusContent(context, r),
      MetaResponse r => _buildMetaContent(context, r),
      CompletionResponse r => _buildCompletionContent(context, r),
      CompactBoundaryResponse r => _buildCompactBoundaryContent(context, r),
      CompactSummaryResponse r => _buildCompactSummaryContent(context, r),
      UnknownResponse() => Text(
          'Unknown response type',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
    };
  }

  Widget _buildTextContent(BuildContext context, TextResponse response) {
    final preview = response.content.length > 300
        ? '${response.content.substring(0, 300)}...'
        : response.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (response.role != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Role: ${response.role}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Text(
          preview,
          style: const TextStyle(fontSize: 13),
        ),
        if (response.isPartial || response.isCumulative)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (response.isPartial)
                  _buildInfoChip('Partial', Colors.orange),
                if (response.isCumulative)
                  _buildInfoChip('Cumulative', Colors.blue),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildToolUseContent(BuildContext context, ToolUseResponse response) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.build, size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              response.toolName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        if (response.toolUseId != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'ID: ${response.toolUseId}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (response.parameters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildParametersPreview(response.parameters),
          ),
      ],
    );
  }

  Widget _buildParametersPreview(Map<String, dynamic> params) {
    final entries = params.entries.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${entry.key}: ',
                    style: const TextStyle(
                      color: Color(0xFF9CDCFE),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text: _truncate(entry.value.toString(), 100),
                    style: const TextStyle(
                      color: Color(0xFFCE9178),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (params.length > 3)
          Text(
            '... and ${params.length - 3} more parameters',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildToolResultContent(BuildContext context, ToolResultResponse response) {
    final preview = response.content.length > 200
        ? '${response.content.substring(0, 200)}...'
        : response.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              response.isError ? Icons.error : Icons.check_circle,
              size: 16,
              color: response.isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              response.isError ? 'Error Result' : 'Success Result',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: response.isError ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Tool Use ID: ${response.toolUseId}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            preview,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMessageContent(BuildContext context, UserMessageResponse response) {
    final preview = response.content.length > 300
        ? '${response.content.substring(0, 300)}...'
        : response.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preview,
          style: const TextStyle(fontSize: 13),
        ),
        if (response.isReplay)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _buildInfoChip('Replay', Colors.purple),
          ),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context, ErrorResponse response) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            response.error,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (response.details != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                response.details!,
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 12,
                ),
              ),
            ),
          if (response.code != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Code: ${response.code}',
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusContent(BuildContext context, StatusResponse response) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          response.status.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        if (response.message != null) ...[
          const SizedBox(width: 8),
          Text(
            response.message!,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaContent(BuildContext context, MetaResponse response) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (response.conversationId != null)
          Text(
            'Conversation ID: ${response.conversationId}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        if (response.metadata.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Metadata keys: ${response.metadata.keys.join(", ")}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompletionContent(BuildContext context, CompletionResponse response) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (response.stopReason != null)
          _buildStatChip('Stop', response.stopReason!, Colors.teal),
        if (response.inputTokens != null)
          _buildStatChip('In', '${response.inputTokens}', Colors.blue),
        if (response.outputTokens != null)
          _buildStatChip('Out', '${response.outputTokens}', Colors.green),
        if (response.cacheReadInputTokens != null && response.cacheReadInputTokens! > 0)
          _buildStatChip('Cache Read', '${response.cacheReadInputTokens}', Colors.purple),
        if (response.cacheCreationInputTokens != null && response.cacheCreationInputTokens! > 0)
          _buildStatChip('Cache Create', '${response.cacheCreationInputTokens}', Colors.orange),
        if (response.totalCostUsd != null)
          _buildStatChip('Cost', '\$${response.totalCostUsd!.toStringAsFixed(4)}', Colors.amber),
      ],
    );
  }

  Widget _buildCompactBoundaryContent(BuildContext context, CompactBoundaryResponse response) {
    return Row(
      children: [
        const Icon(Icons.compress, size: 16, color: Colors.yellow),
        const SizedBox(width: 8),
        Text(
          'Compaction (${response.trigger})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${response.preTokens} tokens before',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSummaryContent(BuildContext context, CompactSummaryResponse response) {
    final preview = response.content.length > 300
        ? '${response.content.substring(0, 300)}...'
        : response.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.summarize, size: 16, color: Colors.pink),
            const SizedBox(width: 8),
            const Text(
              'Compact Summary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (response.isVisibleInTranscriptOnly) ...[
              const SizedBox(width: 8),
              _buildInfoChip('Transcript Only', Colors.pink),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          preview,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
