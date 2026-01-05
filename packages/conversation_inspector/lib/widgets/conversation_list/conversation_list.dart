import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/conversation_metadata.dart';
import '../../services/conversation_discovery_service.dart';
import 'conversation_list_item.dart';

/// The left panel showing all discovered conversations.
class ConversationList extends StatefulWidget {
  final ConversationMetadata? selectedConversation;
  final ValueChanged<ConversationMetadata>? onConversationSelected;

  const ConversationList({
    super.key,
    this.selectedConversation,
    this.onConversationSelected,
  });

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  final _discoveryService = ConversationDiscoveryService();

  List<ConversationMetadata>? _conversations;
  Map<String, List<ConversationMetadata>>? _groupedConversations;
  Set<String> _expandedProjects = {};
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final conversations = await _discoveryService.discoverAllConversations();
      final grouped = await _discoveryService.groupByProject();

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _groupedConversations = grouped;
          _loading = false;
          // Expand all projects by default if there are few
          if (grouped.length <= 5) {
            _expandedProjects = grouped.keys.toSet();
          }
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

  List<ConversationMetadata> _filterConversations(List<ConversationMetadata> convs) {
    if (_searchQuery.isEmpty) return convs;

    final query = _searchQuery.toLowerCase();
    return convs.where((c) {
      return c.projectPath.toLowerCase().contains(query) ||
          c.sessionId.toLowerCase().contains(query) ||
          (c.displayText?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        _buildSearchBar(context),
        Expanded(
          child: _buildContent(context),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline, size: 20),
          const SizedBox(width: 8),
          Text(
            'Conversations',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_conversations != null)
            Text(
              '${_conversations!.length}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 18),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'Show search paths',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loadConversations,
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _showInfoDialog(BuildContext context) async {
    final claudeDir = _discoveryService.claudeDir;
    final projectsDir = '$claudeDir/projects';

    // Check directory existence
    String debugInfo = '';
    try {
      final dir = Directory(projectsDir);
      final exists = await dir.exists();
      debugInfo = 'Projects dir exists: $exists';
      if (exists) {
        final items = await dir.list().take(5).toList();
        debugInfo += '\nFirst 5 items: ${items.map((e) => e.path.split('/').last).join(', ')}';
      }
    } catch (e) {
      debugInfo = 'Error checking dir: $e';
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Paths'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Looking for conversations in:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SelectableText(
                projectsDir,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'History metadata from:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(
                '$claudeDir/history.jsonl',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Found ${_conversations?.length ?? 0} conversations',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Debug info:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(
                debugInfo,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.orange,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  'Last error: $_error',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          prefixIcon: const Icon(Icons.search, size: 18),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading conversations',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_conversations == null || _conversations!.isEmpty) {
      return const Center(
        child: Text('No conversations found'),
      );
    }

    return _buildGroupedList(context);
  }

  Widget _buildGroupedList(BuildContext context) {
    final theme = Theme.of(context);
    final groups = _groupedConversations!;

    // Sort projects by most recent conversation
    final sortedProjects = groups.keys.toList()
      ..sort((a, b) {
        final aTime = groups[a]!.first.lastModified ?? groups[a]!.first.timestamp ?? DateTime(1970);
        final bTime = groups[b]!.first.lastModified ?? groups[b]!.first.timestamp ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

    return ListView.builder(
      itemCount: sortedProjects.length,
      itemBuilder: (context, index) {
        final projectPath = sortedProjects[index];
        final conversations = _filterConversations(groups[projectPath]!);

        if (conversations.isEmpty && _searchQuery.isNotEmpty) {
          return const SizedBox.shrink();
        }

        final isExpanded = _expandedProjects.contains(projectPath);
        final projectName = projectPath.split('/').where((p) => p.isNotEmpty).lastOrNull ?? projectPath;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedProjects.remove(projectPath);
                  } else {
                    _expandedProjects.add(projectPath);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                child: Row(
                  children: [
                    Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        projectName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${conversations.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              ...conversations.map((conv) => ConversationListItem(
                    conversation: conv,
                    isSelected: widget.selectedConversation == conv,
                    onTap: () => widget.onConversationSelected?.call(conv),
                  )),
          ],
        );
      },
    );
  }
}
