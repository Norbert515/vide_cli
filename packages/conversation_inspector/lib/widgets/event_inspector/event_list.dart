import 'package:flutter/material.dart';

import '../../models/raw_event.dart';
import 'event_item.dart';

/// A scrollable list of events from a conversation.
class EventList extends StatelessWidget {
  final List<RawEvent> events;
  final int? selectedIndex;
  final ValueChanged<int>? onEventSelected;
  final ScrollController? scrollController;

  const EventList({
    super.key,
    required this.events,
    this.selectedIndex,
    this.onEventSelected,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text('No events in this conversation'),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return EventItem(
          event: event,
          isSelected: index == selectedIndex,
          onTap: () => onEventSelected?.call(index),
        );
      },
    );
  }
}
