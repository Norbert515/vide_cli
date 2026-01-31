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
  StreamSubscription<ConnectivityResult>? _subscription;
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
    // connectivity_plus v5.x returns Stream<ConnectivityResult>
    _subscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        state = _resultToStatus(result);
      },
    );
  }

  Future<void> _checkConnectivity() async {
    // connectivity_plus v5.x returns ConnectivityResult
    final result = await _connectivity.checkConnectivity();
    state = _resultToStatus(result);
  }

  NetworkStatus _resultToStatus(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
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
