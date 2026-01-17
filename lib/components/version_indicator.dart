import 'dart:async';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_core/api.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

/// Displays the current version and auto-update status in the top right corner.
///
/// Shows:
/// - Version number when idle/up-to-date
/// - "Checking..." when checking for updates
/// - Download progress when downloading
/// - "Restart for v{X.Y.Z}" when update ready
class VersionIndicator extends StatefulComponent {
  const VersionIndicator({super.key});

  @override
  State<VersionIndicator> createState() => _VersionIndicatorState();
}

class _VersionIndicatorState extends State<VersionIndicator> {
  static const _spinnerFrames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];
  Timer? _spinnerTimer;
  int _spinnerIndex = 0;
  UpdateStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    // Trigger initial update check after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.read(autoUpdateServiceProvider.notifier).checkForUpdates();
      }
    });
  }

  void _startSpinner() {
    if (_spinnerTimer != null) return; // Already running
    _spinnerTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _spinnerIndex = (_spinnerIndex + 1) % _spinnerFrames.length;
      });
    });
  }

  void _stopSpinner() {
    _spinnerTimer?.cancel();
    _spinnerTimer = null;
  }

  void _updateSpinnerForStatus(UpdateStatus status) {
    final wasDownloading = _lastStatus == UpdateStatus.downloading;
    final isDownloading = status == UpdateStatus.downloading;

    if (isDownloading && !wasDownloading) {
      _startSpinner();
    } else if (!isDownloading && wasDownloading) {
      _stopSpinner();
    } else if (isDownloading && _spinnerTimer == null) {
      // Handle initial mount with downloading status
      _startSpinner();
    }

    _lastStatus = status;
  }

  @override
  void dispose() {
    _stopSpinner();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final updateState = context.watch(autoUpdateServiceProvider);

    // Start/stop spinner based on status changes (only runs when downloading)
    _updateSpinnerForStatus(updateState.status);

    return _buildContent(theme, updateState);
  }

  Component _buildContent(VideThemeData theme, UpdateState updateState) {
    switch (updateState.status) {
      case UpdateStatus.idle:
      case UpdateStatus.upToDate:
      case UpdateStatus.checking:
      case UpdateStatus.error:
        // Show version number with subtle styling (don't distract user during checking)
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'v${updateState.currentVersion}',
              style: TextStyle(
                color: theme.base.onSurface.withOpacity(TextOpacity.tertiary),
              ),
            ),
          ],
        );

      case UpdateStatus.downloading:
        final percentage = (updateState.downloadProgress * 100).toInt();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _spinnerFrames[_spinnerIndex],
              style: TextStyle(color: theme.base.primary),
            ),
            const SizedBox(width: 1),
            Text(
              'updating $percentage%',
              style: TextStyle(color: theme.base.primary),
            ),
          ],
        );

      case UpdateStatus.readyToRestart:
        final newVersion = updateState.updateInfo?.latestVersion ?? '?';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'v$newVersion ready - restart to apply',
              style: TextStyle(color: theme.base.primary),
            ),
          ],
        );
    }
  }
}

/// Compact version indicator that just shows version or update status icon
class VersionIndicatorCompact extends StatefulComponent {
  const VersionIndicatorCompact({super.key});

  @override
  State<VersionIndicatorCompact> createState() =>
      _VersionIndicatorCompactState();
}

class _VersionIndicatorCompactState extends State<VersionIndicatorCompact> {
  @override
  void initState() {
    super.initState();
    // Trigger initial update check after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.read(autoUpdateServiceProvider.notifier).checkForUpdates();
      }
    });
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final updateState = context.watch(autoUpdateServiceProvider);

    final text = _getText(updateState);
    final color = _getColor(updateState, theme);

    return Text(text, style: TextStyle(color: color));
  }

  String _getText(UpdateState updateState) {
    switch (updateState.status) {
      case UpdateStatus.idle:
      case UpdateStatus.upToDate:
      case UpdateStatus.error:
      case UpdateStatus.checking:
        return 'v${updateState.currentVersion}';
      case UpdateStatus.downloading:
        return '↓${(updateState.downloadProgress * 100).toInt()}%';
      case UpdateStatus.readyToRestart:
        return '↻v${updateState.updateInfo?.latestVersion ?? '?'}';
    }
  }

  Color _getColor(UpdateState updateState, VideThemeData theme) {
    switch (updateState.status) {
      case UpdateStatus.idle:
      case UpdateStatus.upToDate:
      case UpdateStatus.error:
      case UpdateStatus.checking:
        return theme.base.onSurface.withOpacity(TextOpacity.tertiary);
      case UpdateStatus.downloading:
        return theme.base.primary;
      case UpdateStatus.readyToRestart:
        return theme.base.primary;
    }
  }
}
