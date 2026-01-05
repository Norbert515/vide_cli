import 'package:claude_sdk/claude_sdk.dart';
import 'package:flutter/material.dart';

import '../../models/raw_event.dart';

/// A color-coded badge showing the type of a Claude response.
class EventTypeBadge extends StatelessWidget {
  final RawEvent event;
  final bool showRawType;

  const EventTypeBadge({
    super.key,
    required this.event,
    this.showRawType = false,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label) = _getColorAndLabel();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  (Color, String) _getColorAndLabel() {
    if (showRawType) {
      return _getRawTypeColorAndLabel();
    }

    final response = event.parsedResponse;
    if (response == null) {
      if (event.hasParseError) {
        return (Colors.red, 'ParseError');
      }
      return (Colors.grey, event.rawType);
    }

    return switch (response) {
      TextResponse _ => (Colors.blue, 'Text'),
      ToolUseResponse _ => (Colors.orange, 'ToolUse'),
      ToolResultResponse _ => (Colors.green, 'ToolResult'),
      UserMessageResponse _ => (Colors.cyan, 'User'),
      ErrorResponse _ => (Colors.red, 'Error'),
      StatusResponse _ => (Colors.grey, 'Status'),
      MetaResponse _ => (Colors.purple, 'Meta'),
      CompletionResponse _ => (Colors.teal, 'Completion'),
      CompactBoundaryResponse _ => (Colors.yellow.shade700, 'CompactBoundary'),
      CompactSummaryResponse _ => (Colors.pink, 'CompactSummary'),
      UnknownResponse _ => (Colors.grey.shade600, 'Unknown'),
    };
  }

  (Color, String) _getRawTypeColorAndLabel() {
    final type = event.rawType;
    final subtype = event.rawSubtype;

    final label = subtype.isNotEmpty ? '$type:$subtype' : type;

    return switch (type) {
      'user' => (Colors.cyan, label),
      'assistant' => (Colors.blue, label),
      'system' => (Colors.purple, label),
      'error' => (Colors.red, label),
      'result' => (Colors.teal, label),
      'tool_use' => (Colors.orange, label),
      'text' => (Colors.blue.shade300, label),
      'message' => (Colors.blue.shade300, label),
      'status' => (Colors.grey, label),
      'meta' => (Colors.purple.shade300, label),
      'completion' => (Colors.teal.shade300, label),
      'stream_event' => (Colors.indigo, label),
      _ => (Colors.grey.shade600, label),
    };
  }
}

/// A row showing both parsed and raw type badges.
class EventTypeBadges extends StatelessWidget {
  final RawEvent event;

  const EventTypeBadges({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EventTypeBadge(event: event, showRawType: false),
        const SizedBox(width: 4),
        EventTypeBadge(event: event, showRawType: true),
        if (event.isMeta) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.amber.withOpacity(0.5)),
            ),
            child: const Text(
              'META',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
