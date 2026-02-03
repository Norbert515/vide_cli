import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/connection_state_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';
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
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    final (icon, message, showRetry, backgroundColor) = switch (connectionState.status) {
      WebSocketConnectionStatus.connecting => (
          Icons.sync,
          'Connecting...',
          false,
          videColors.accentSubtle,
        ),
      WebSocketConnectionStatus.reconnecting => (
          Icons.sync,
          'Reconnecting (${connectionState.retryCount}/${connectionState.maxRetries})...',
          false,
          videColors.warningContainer,
        ),
      WebSocketConnectionStatus.disconnected => networkStatus == NetworkStatus.offline
          ? (
              Icons.wifi_off,
              'No internet connection',
              false,
              videColors.errorContainer,
            )
          : (
              Icons.cloud_off,
              connectionState.errorMessage ?? 'Disconnected',
              false,
              videColors.errorContainer,
            ),
      WebSocketConnectionStatus.failed => (
          Icons.error_outline,
          connectionState.errorMessage ?? 'Connection failed',
          true,
          videColors.errorContainer,
        ),
      WebSocketConnectionStatus.connected => (
          Icons.check_circle,
          'Connected',
          false,
          videColors.successContainer,
        ),
    };

    return AnimatedContainer(
      duration: VideDurations.normal,
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VideSpacing.md,
            vertical: VideSpacing.sm,
          ),
          child: Row(
            children: [
              if (connectionState.status == WebSocketConnectionStatus.connecting ||
                  connectionState.status == WebSocketConnectionStatus.reconnecting)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: videColors.accent,
                  ),
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
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    final (icon, color, label) = switch (connectionState.status) {
      WebSocketConnectionStatus.connected => (
          Icons.check_circle,
          videColors.success,
          null as String?,
        ),
      WebSocketConnectionStatus.connecting => (
          Icons.sync,
          videColors.warning,
          'Connecting',
        ),
      WebSocketConnectionStatus.reconnecting => (
          Icons.sync,
          videColors.warning,
          '${connectionState.retryCount}/${connectionState.maxRetries}',
        ),
      WebSocketConnectionStatus.disconnected => networkStatus == NetworkStatus.offline
          ? (Icons.wifi_off, videColors.error, 'Offline')
          : (Icons.cloud_off, videColors.error, 'Disconnected'),
      WebSocketConnectionStatus.failed => (
          Icons.error_outline,
          videColors.error,
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
        borderRadius: BorderRadius.circular(VideRadius.sm),
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
