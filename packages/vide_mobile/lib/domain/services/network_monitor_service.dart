import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_monitor_service.g.dart';

/// Represents the current network status.
enum NetworkStatus {
  /// Device is connected to the internet.
  online,

  /// Device has no internet connection.
  offline,

  /// Network status is unknown.
  unknown,
}

/// Provider for monitoring network connectivity.
@Riverpod(keepAlive: true)
class NetworkMonitor extends _$NetworkMonitor {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final Connectivity _connectivity = Connectivity();

  @override
  NetworkStatus build() {
    ref.onDispose(() {
      _subscription?.cancel();
    });

    // Start monitoring immediately
    _startMonitoring();

    // Check initial status
    _checkConnectivity();

    return NetworkStatus.unknown;
  }

  void _startMonitoring() {
    _subscription = _connectivity.onConnectivityChanged.listen(
      (result) {
        // Handle both single result and list depending on package version
        final results = result is List ? result : [result];
        final status = _resultsToStatus(results as List<ConnectivityResult>);
        state = status;
      },
    ) as StreamSubscription<List<ConnectivityResult>>?;
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    // Handle both single result and list depending on package version
    final results = result is List ? result : [result];
    state = _resultsToStatus(results as List<ConnectivityResult>);
  }

  NetworkStatus _resultsToStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }

  /// Check if we're currently online.
  bool get isOnline => state == NetworkStatus.online;

  /// Check if we're currently offline.
  bool get isOffline => state == NetworkStatus.offline;

  /// Force a connectivity check.
  Future<void> refresh() async {
    await _checkConnectivity();
  }
}
