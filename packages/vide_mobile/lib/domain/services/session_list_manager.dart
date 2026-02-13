import 'dart:async';
import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';

import '../../data/repositories/connection_repository.dart';

part 'session_list_manager.g.dart';

/// The type of the latest activity shown in the session card.
enum LatestActivityType { message, toolUse }

/// Represents the latest activity in a session (message or tool call).
class LatestActivity {
  final LatestActivityType type;
  final String text;
  final String? subtitle;

  const LatestActivity({required this.type, required this.text, this.subtitle});
}

/// An entry in the session list, combining daemon summary with live state.
class SessionListEntry {
  final SessionSummary summary;
  final RemoteVideSession? session;
  final DateTime? lastEventAt;
  final LatestActivity? latestActivity;

  const SessionListEntry({
    required this.summary,
    this.session,
    this.lastEventAt,
    this.latestActivity,
  });

  /// Sort key: most recent activity or creation time.
  DateTime get sortTime => lastEventAt ?? summary.createdAt;

  /// Pending permission from the remote session (if any).
  PermissionRequestEvent? get pendingPermission =>
      session?.pendingPermissionRequest;
}

/// A group of sessions sharing the same working directory (project).
class SessionGroup {
  final String workingDirectory;
  final List<SessionListEntry> entries;

  const SessionGroup({required this.workingDirectory, required this.entries});

  /// Project display name — just the directory name, not the full path.
  String get projectName {
    final parts = workingDirectory.split('/');
    return parts.isNotEmpty ? parts.last : workingDirectory;
  }
}

/// Manages RemoteVideSession instances for all sessions on the list screen.
///
/// Single source of truth for the session list: fetches from daemon,
/// connects via RemoteVideSession, and tracks live activity.
@Riverpod(keepAlive: true)
class SessionListManager extends _$SessionListManager {
  final Map<String, RemoteVideSession> _sessions = {};
  final Map<String, List<StreamSubscription<dynamic>>> _subscriptions = {};

  void _log(String message) {
    developer.log(message, name: 'SessionListManager');
  }

  @override
  Map<String, SessionListEntry> build() {
    ref.onDispose(_disposeAll);
    return const {};
  }

  void _disposeAll() {
    for (final subs in _subscriptions.values) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _subscriptions.clear();
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
  }

  /// Fetch sessions from daemon and start monitoring new ones.
  Future<void> refresh() async {
    final connectionState = ref.read(connectionRepositoryProvider);
    if (!connectionState.isConnected || connectionState.client == null) return;

    final client = connectionState.client!;
    final summaries = await client.listSessions();
    _updateSessions(client, summaries);
  }

  void _updateSessions(VideClient client, List<SessionSummary> summaries) {
    final currentIds = _sessions.keys.toSet();
    final newIds = summaries.map((s) => s.sessionId).toSet();

    // Remove sessions that no longer exist
    for (final id in currentIds.difference(newIds)) {
      _removeSession(id);
    }

    // Add or update sessions
    for (final summary in summaries) {
      final id = summary.sessionId;
      final existing = state[id];

      if (existing != null) {
        // Update summary (state/connectedClients may change)
        state = {...state, id: SessionListEntry(
          summary: summary,
          session: existing.session,
          lastEventAt: existing.lastEventAt,
          latestActivity: existing.latestActivity,
        )};
      } else {
        // New session
        state = {...state, id: SessionListEntry(summary: summary)};
        _connectToSession(client, id);
      }
    }
  }

  void _removeSession(String id) {
    _log('Removing session $id');
    for (final sub in _subscriptions[id] ?? []) {
      sub.cancel();
    }
    _subscriptions.remove(id);
    _sessions[id]?.dispose();
    _sessions.remove(id);
    state = Map.fromEntries(state.entries.where((e) => e.key != id));
  }

  Future<void> _connectToSession(VideClient client, String id) async {
    _log('Connecting to session $id');
    try {
      final session = await client.connectToSession(id);
      _sessions[id] = session;

      final entry = state[id];
      if (entry == null) {
        session.dispose();
        return;
      }

      state = {...state, id: SessionListEntry(
        summary: entry.summary,
        session: session,
        lastEventAt: entry.lastEventAt,
        latestActivity: entry.latestActivity,
      )};

      // Single event listener for activity tracking + state rebuilds
      _subscriptions[id] = [
        session.events.listen(
          (event) => _handleEvent(id, event),
          onError: (_) {},
        ),
        session.stateStream.map((s) => s.goal).distinct().listen((_) => _notify(id)),
        session.stateStream.map((s) => s.agents).distinct().listen((_) => _notify(id)),
        session.stateStream.map((s) => s.isProcessing).distinct().listen((_) => _notify(id)),
      ];
    } catch (e) {
      _log('Failed to connect to session $id: $e');
    }
  }

  void _handleEvent(String id, VideEvent event) {
    final entry = state[id];
    if (entry == null) return;

    LatestActivity? activity = entry.latestActivity;

    switch (event) {
      case MessageEvent() when !event.isPartial && event.content.isNotEmpty:
        activity = LatestActivity(
          type: LatestActivityType.message,
          text: event.content,
        );
      case ToolUseEvent():
        final name = _stripMcpPrefix(event.toolName);
        activity = LatestActivity(
          type: LatestActivityType.toolUse,
          text: name,
          subtitle: _toolSubtitle(name, event.toolInput),
        );
      case PermissionRequestEvent():
      case PermissionResolvedEvent():
        // Permission state is read directly from session.pendingPermissionRequest
        _notify(id);
        return;
      default:
        // Update lastEventAt even for events that don't change activity
        break;
    }

    state = {...state, id: SessionListEntry(
      summary: entry.summary,
      session: entry.session,
      lastEventAt: DateTime.now(),
      latestActivity: activity,
    )};
  }

  /// Force a rebuild for a session without changing its data.
  void _notify(String id) {
    final entry = state[id];
    if (entry != null) {
      state = {...state};
    }
  }

  /// Respond to a permission request.
  void respondToPermission(
    String sessionId,
    String requestId, {
    required bool allow,
  }) {
    _sessions[sessionId]?.respondToPermission(requestId, allow: allow);
  }

  /// Entries grouped by project, each group sorted by creation time (stable).
  ///
  /// Groups are ordered by the most recently created session in each group.
  /// Within each group, sessions are ordered newest first.
  List<SessionGroup> get groupedEntries {
    final entries = state.values.toList();

    // Group by working directory
    final groups = <String, List<SessionListEntry>>{};
    for (final entry in entries) {
      final dir = entry.summary.workingDirectory;
      groups.putIfAbsent(dir, () => []).add(entry);
    }

    // Sort sessions within each group by creation time (newest first)
    for (final group in groups.values) {
      group.sort(
        (a, b) => b.summary.createdAt.compareTo(a.summary.createdAt),
      );
    }

    // Sort groups by the most recently created session in each group
    final sortedGroups = groups.entries.toList()
      ..sort((a, b) {
        final aNewest = a.value.first.summary.createdAt;
        final bNewest = b.value.first.summary.createdAt;
        return bNewest.compareTo(aNewest);
      });

    return sortedGroups
        .map((e) => SessionGroup(workingDirectory: e.key, entries: e.value))
        .toList();
  }

  /// Flat sorted entries (most recently created first) — stable sort.
  List<SessionListEntry> get sortedEntries {
    final entries = state.values.toList();
    entries.sort(
      (a, b) => b.summary.createdAt.compareTo(a.summary.createdAt),
    );
    return entries;
  }

  static String _stripMcpPrefix(String toolName) {
    final mcpPrefix = RegExp(r'^mcp__[^_]+__');
    return toolName.replaceFirst(mcpPrefix, '');
  }

  static String? _toolSubtitle(String name, Map<String, dynamic> input) {
    return switch (name) {
      'Read' || 'Edit' || 'Write' => input['file_path'] as String?,
      'Bash' => input['command'] as String?,
      'Grep' => _grepSubtitle(input),
      'Glob' => input['pattern'] as String?,
      'WebFetch' => input['url'] as String?,
      'WebSearch' => input['query'] as String?,
      _ => input['file_path'] as String? ??
          input['command'] as String? ??
          input['pattern'] as String? ??
          input['description'] as String?,
    };
  }

  static String? _grepSubtitle(Map<String, dynamic> input) {
    final pattern = input['pattern'] as String?;
    final path = input['path'] as String?;
    if (pattern != null && path != null) return '"$pattern" in $path';
    return pattern != null ? '"$pattern"' : null;
  }
}
