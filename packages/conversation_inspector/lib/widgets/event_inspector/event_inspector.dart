import 'package:flutter/material.dart';

import '../../models/conversation_metadata.dart';
import '../../models/raw_event.dart';
import '../../services/conversation_loading_service.dart';
import 'event_list.dart';

/// The main event inspector panel showing all events in a conversation.
class EventInspector extends StatefulWidget {
  final ConversationMetadata? conversation;

  const EventInspector({
    super.key,
    this.conversation,
  });

  @override
  State<EventInspector> createState() => _EventInspectorState();
}

class _EventInspectorState extends State<EventInspector> {
  final _loadingService = ConversationLoadingService();
  final _scrollController = ScrollController();

  List<RawEvent>? _events;
  ConversationStats? _stats;
  bool _loading = false;
  String? _error;
  int? _selectedEventIndex;
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    if (widget.conversation != null) {
      _loadEvents();
    }
  }

  @override
  void didUpdateWidget(EventInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversation != oldWidget.conversation) {
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    if (widget.conversation == null) {
      setState(() {
        _events = null;
        _stats = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _selectedEventIndex = null;
    });

    try {
      final events = await _loadingService.loadConversation(widget.conversation!);
      final stats = ConversationStats.fromEvents(events);

      if (mounted) {
        setState(() {
          _events = events;
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<RawEvent> get _filteredEvents {
    if (_events == null) return [];
    if (_typeFilter == null) return _events!;

    return _events!.where((e) {
      if (_typeFilter == 'meta') return e.isMeta;
      if (_typeFilter == 'error') return e.hasParseError;
      return e.parsedTypeName == _typeFilter || e.rawType == _typeFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.conversation == null) {
      return const Center(
        child: Text(
          'Select a conversation to inspect',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading conversation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(context),
        if (_stats != null) _buildStats(context),
        Expanded(
          child: EventList(
            events: _filteredEvents,
            selectedIndex: _selectedEventIndex,
            onEventSelected: (index) {
              setState(() => _selectedEventIndex = index);
            },
            scrollController: _scrollController,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final conv = widget.conversation!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conv.projectName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conv.projectPath,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadEvents,
                tooltip: 'Reload',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Session: ${conv.sessionId}',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final stats = _stats!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${stats.totalEvents} events',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', null),
                  _buildFilterChip('User (${stats.userMessages})', 'UserMessageResponse'),
                  _buildFilterChip('Text (${stats.assistantMessages})', 'TextResponse'),
                  _buildFilterChip('Tools (${stats.toolUses})', 'ToolUseResponse'),
                  _buildFilterChip('Results (${stats.toolResults})', 'ToolResultResponse'),
                  if (stats.metaMessages > 0)
                    _buildFilterChip('Meta (${stats.metaMessages})', 'meta'),
                  if (stats.errors > 0)
                    _buildFilterChip('Errors (${stats.errors})', 'ErrorResponse'),
                  if (stats.parseErrors > 0)
                    _buildFilterChip('Parse Errors (${stats.parseErrors})', 'error'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? filter) {
    final isSelected = _typeFilter == filter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(fontSize: 12),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _typeFilter = selected ? filter : null;
            _selectedEventIndex = null;
          });
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
