import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/connection_state_provider.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../domain/services/network_monitor_service.dart';

/// Banner displayed at the top of chat screen showing connection status.
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(webSocketConnectionProvider);
    final networkStatus = ref.watch(networkMonitorProvider);

    // Don't show banner when connected
    if (connectionState.status == WebSocketConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    return _buildBanner(context, ref, connectionState, networkStatus);
  }

  Widget _buildBanner(
    BuildContext context,
    WidgetRef ref,
    WebSocketConnectionState connectionState,
    NetworkStatus networkStatus,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final (icon, message, showRetry, backgroundColor) = switch (connectionState.status) {
      WebSocketConnectionStatus.connecting => (
          Icons.sync,
          'Connecting...',
          false,
          colorScheme.primaryContainer,
        ),
      WebSocketConnectionStatus.reconnecting => (
          Icons.sync,
          'Reconnecting (${connectionState.retryCount}/${connectionState.maxRetries})...',
          false,
          colorScheme.tertiaryContainer,
        ),
      WebSocketConnectionStatus.disconnected => networkStatus == NetworkStatus.offline
          ? (
              Icons.wifi_off,
              'No internet connection',
              false,
              colorScheme.errorContainer,
            )
          : (
              Icons.cloud_off,
              connectionState.errorMessage ?? 'Disconnected',
              false,
              colorScheme.errorContainer,
            ),
      WebSocketConnectionStatus.failed => (
          Icons.error_outline,
          connectionState.errorMessage ?? 'Connection failed',
          true,
          colorScheme.errorContainer,
        ),
      WebSocketConnectionStatus.connected => (
          Icons.check_circle,
          'Connected',
          false,
          colorScheme.primaryContainer,
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (connectionState.status == WebSocketConnectionStatus.connecting ||
                  connectionState.status == WebSocketConnectionStatus.reconnecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (showRetry)
                TextButton(
                  onPressed: () {
                    ref.read(sessionRepositoryProvider.notifier).manualReconnect();
                  },
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small chip showing connection status in the app bar.
class ConnectionStatusChip extends ConsumerWidget {
  const ConnectionStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(webSocketConnectionProvider);
    final networkStatus = ref.watch(networkMonitorProvider);

    final (icon, color, label) = switch (connectionState.status) {
      WebSocketConnectionStatus.connected => (
          Icons.check_circle,
          Colors.green,
          null as String?,
        ),
      WebSocketConnectionStatus.connecting => (
          Icons.sync,
          Colors.orange,
          'Connecting',
        ),
      WebSocketConnectionStatus.reconnecting => (
          Icons.sync,
          Colors.orange,
          '${connectionState.retryCount}/${connectionState.maxRetries}',
        ),
      WebSocketConnectionStatus.disconnected => networkStatus == NetworkStatus.offline
          ? (Icons.wifi_off, Colors.red, 'Offline')
          : (Icons.cloud_off, Colors.red, 'Disconnected'),
      WebSocketConnectionStatus.failed => (
          Icons.error_outline,
          Colors.red,
          'Failed',
        ),
    };

    // Show minimal indicator when connected
    if (connectionState.status == WebSocketConnectionStatus.connected) {
      return Icon(icon, size: 16, color: color);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connectionState.status == WebSocketConnectionStatus.connecting ||
              connectionState.status == WebSocketConnectionStatus.reconnecting)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          else
            Icon(icon, size: 14, color: color),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
