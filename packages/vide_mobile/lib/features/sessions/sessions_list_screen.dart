import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/vide_colors.dart';
import '../../data/repositories/server_registry.dart';
import '../../domain/services/session_list_manager.dart';

part 'sessions_list_screen.g.dart';

/// Triggers a refresh of the session list from the daemon.
///
/// The actual session data lives in [sessionListManagerProvider] (keepAlive).
/// This provider just kicks off the fetch; the screen watches the manager
/// directly for live updates.
@riverpod
Future<void> sessionsListRefresh(Ref ref) async {
  ref.watch(serverRegistryProvider);
  await ref.read(sessionListManagerProvider.notifier).refresh();
}

/// Screen showing list of existing sessions.
class SessionsListScreen extends ConsumerWidget {
  const SessionsListScreen({super.key});

  Future<void> _stopSession(
    BuildContext context,
    WidgetRef ref,
    SessionListEntry entry,
  ) async {
    final session = entry.summary;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop session?'),
        content: Text(
          'This will stop session "${session.sessionId}" and terminate all agents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final registry = ref.read(serverRegistryProvider.notifier);
    final client = registry.getClient(entry.serverId);
    if (client == null) return;

    try {
      await client.stopSession(session.sessionId);
      ref.invalidate(sessionsListRefreshProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop session: $e'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<SessionGroup> groups,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No active sessions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new session to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    final showHeaders = groups.length > 1;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sessionsListRefreshProvider);
        await ref.read(sessionsListRefreshProvider.future);
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: _countItems(groups, showHeaders),
        itemBuilder: (context, index) {
          final item = _itemAt(groups, index, showHeaders);
          if (item is SessionGroup) {
            return _ProjectHeader(
              projectName: item.projectName,
            );
          }
          final entry = item as SessionListEntry;
          return _SessionCard(
            entry: entry,
            onStop: () => _stopSession(context, ref, entry),
          );
        },
      ),
    );
  }

  /// Count total items (headers + cards) for the flat list.
  int _countItems(List<SessionGroup> groups, bool showHeaders) {
    if (!showHeaders) {
      return groups.fold(0, (sum, g) => sum + g.entries.length);
    }
    // Each group contributes 1 header + N entries.
    return groups.fold(0, (sum, g) => sum + 1 + g.entries.length);
  }

  /// Map a flat index to either a [SessionGroup] (header) or [SessionListEntry].
  Object _itemAt(List<SessionGroup> groups, int index, bool showHeaders) {
    var cursor = 0;
    for (final group in groups) {
      if (showHeaders) {
        if (cursor == index) return group;
        cursor++;
      }
      if (index < cursor + group.entries.length) {
        return group.entries[index - cursor];
      }
      cursor += group.entries.length;
    }
    return groups.last.entries.last;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refreshAsync = ref.watch(sessionsListRefreshProvider);
    final managerState = ref.watch(sessionListManagerProvider);
    final groups = ref.read(sessionListManagerProvider.notifier).groupedEntries;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(sessionsListRefreshProvider),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: refreshAsync.when(
        loading: () => managerState.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _buildList(context, ref, groups),
        error: (error, _) => managerState.isNotEmpty
            ? _buildList(context, ref, groups)
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load sessions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () =>
                          ref.invalidate(sessionsListRefreshProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
        data: (_) => _buildList(context, ref, groups),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newSession),
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  final String projectName;

  const _ProjectHeader({required this.projectName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Icon(
            Icons.folder_outlined,
            size: 16,
            color: colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Text(
            projectName,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: colorScheme.outlineVariant,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final SessionListEntry entry;
  final VoidCallback? onStop;

  const _SessionCard({
    required this.entry,
    this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final session = entry.summary;
    final remoteSession = entry.session;
    final isReady = session.state == 'ready';
    final statusColor = isReady ? videColors.success : videColors.warning;

    // Format the working directory to show just the project name
    final dirParts = session.workingDirectory.split('/');
    final shortDir =
        dirParts.isNotEmpty ? dirParts.last : session.workingDirectory;

    // Format time ago using last activity or creation time
    final timeAgo = _formatTimeAgo(entry.sortTime);

    // Live data from RemoteVideSession
    final latestActivity = entry.latestActivity;
    final pendingPermission = entry.pendingPermission;
    final agentCount = remoteSession?.state.agents.length ?? 1;
    final anyAgentBusy = remoteSession?.state.isProcessing ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: isReady
            ? () => context.push(AppRoutes.sessionPath(session.sessionId))
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Session title (goal or session ID)
                  Expanded(
                    child: Text(
                      remoteSession?.state.goal ??
                          'Session ${session.sessionId.substring(0, 8)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Connected clients badge
                  if (session.connectedClients > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${session.connectedClients}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Working directory
              Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 16,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      shortDir,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Server badge (only when multiple servers are configured)
              Builder(builder: (context) {
                final serverCount = ref.watch(serverRegistryProvider).length;
                if (serverCount <= 1) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        size: 14,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.serverName,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                      ),
                    ],
                  ),
                );
              }),
              // Latest activity preview (message or tool call)
              if (latestActivity != null) ...[
                const SizedBox(height: 6),
                _LatestActivityWidget(
                  activity: latestActivity,
                  colorScheme: colorScheme,
                  videColors: videColors,
                ),
              ],
              // Inline permission request
              if (pendingPermission != null) ...[
                const SizedBox(height: 8),
                _InlinePermissionWidget(
                  permission: pendingPermission,
                  colorScheme: colorScheme,
                  videColors: videColors,
                  onAllow: () => ref
                      .read(sessionListManagerProvider.notifier)
                      .respondToPermission(
                        session.sessionId,
                        pendingPermission.requestId,
                        allow: true,
                      ),
                  onDeny: () => ref
                      .read(sessionListManagerProvider.notifier)
                      .respondToPermission(
                        session.sessionId,
                        pendingPermission.requestId,
                        allow: false,
                      ),
                ),
              ],
              const SizedBox(height: 4),
              // Metadata row
              Row(
                children: [
                  // Agent count
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$agentCount agent${agentCount != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                  const SizedBox(width: 16),
                  // Time ago
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeAgo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                  const Spacer(),
                  // Status indicator — show spinner if any agent is busy
                  if (anyAgentBusy)
                    _BrailleSpinner(color: videColors.accent)
                  else
                    Text(
                      session.state,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  const SizedBox(width: 8),
                  // Stop button
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(
                        Icons.stop_circle_outlined,
                        color: colorScheme.outline,
                      ),
                      onPressed: onStop,
                      tooltip: 'Stop session',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

/// Displays the latest activity: either a message preview or a tool call.
class _LatestActivityWidget extends StatelessWidget {
  final LatestActivity activity;
  final ColorScheme colorScheme;
  final VideThemeColors videColors;

  const _LatestActivityWidget({
    required this.activity,
    required this.colorScheme,
    required this.videColors,
  });

  @override
  Widget build(BuildContext context) {
    switch (activity.type) {
      case LatestActivityType.message:
        return Text(
          activity.text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      case LatestActivityType.toolUse:
        return Row(
          children: [
            Icon(
              Icons.build_outlined,
              size: 13,
              color: videColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              activity.text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: videColors.accent,
              ),
            ),
            if (activity.subtitle != null) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activity.subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        );
    }
  }
}

/// Braille spinner for indicating active work.
class _BrailleSpinner extends StatefulWidget {
  final Color color;

  const _BrailleSpinner({required this.color});

  @override
  State<_BrailleSpinner> createState() => _BrailleSpinnerState();
}

class _BrailleSpinnerState extends State<_BrailleSpinner>
    with SingleTickerProviderStateMixin {
  static const _frames = [
    '\u280B',
    '\u2819',
    '\u2839',
    '\u2838',
    '\u283C',
    '\u2834',
    '\u2826',
    '\u2827',
    '\u2807',
    '\u280F',
  ];

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final frameIndex =
            (_controller.value * _frames.length).floor() % _frames.length;
        return Text(
          _frames[frameIndex],
          style: TextStyle(fontSize: 12, color: widget.color),
        );
      },
    );
  }
}

/// Inline permission request with allow/deny buttons.
class _InlinePermissionWidget extends StatelessWidget {
  final PermissionRequestEvent permission;
  final ColorScheme colorScheme;
  final VideThemeColors videColors;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const _InlinePermissionWidget({
    required this.permission,
    required this.colorScheme,
    required this.videColors,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = _stripMcpPrefix(permission.toolName);
    final subtitle = _permissionSubtitle(displayName, permission.toolInput);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: videColors.warningContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_outlined,
                size: 14,
                color: videColors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: onDeny,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: videColors.error,
                      side: BorderSide(color: videColors.error),
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Deny'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: FilledButton(
                    onPressed: onAllow,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Allow'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _stripMcpPrefix(String toolName) {
    final mcpPrefix = RegExp(r'^mcp__[^_]+__');
    return toolName.replaceFirst(mcpPrefix, '');
  }

  static String? _permissionSubtitle(
    String displayName,
    Map<String, dynamic> input,
  ) {
    switch (displayName) {
      case 'Read':
      case 'Edit':
      case 'Write':
        return input['file_path'] as String?;
      case 'Bash':
        return input['command'] as String?;
      case 'Grep':
        final pattern = input['pattern'] as String?;
        return pattern != null ? '"$pattern"' : null;
      default:
        return input['file_path'] as String? ??
            input['command'] as String? ??
            input['description'] as String?;
    }
  }
}
