import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vide_client/vide_client.dart';

import '../../data/repositories/server_registry.dart';

part 'git_status_provider.g.dart';

@riverpod
class GitStatusNotifier extends _$GitStatusNotifier {
  Timer? _pollTimer;
  bool _disposed = false;

  @override
  GitStatusInfo? build(String workingDirectory) {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _pollTimer?.cancel();
    });
    _fetchStatus();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchStatus(),
    );
    return null;
  }

  Future<void> _fetchStatus() async {
    if (_disposed) return;
    final registry = ref.read(serverRegistryProvider.notifier);
    final connected = registry.connectedEntries;
    if (connected.isEmpty || connected.first.client == null) return;
    final client = connected.first.client!;

    try {
      final status = await client.gitStatus(workingDirectory, detailed: true);
      if (_disposed) return;
      state = status;
    } catch (_) {
      // Network errors — badge just won't update.
    }
  }
}
