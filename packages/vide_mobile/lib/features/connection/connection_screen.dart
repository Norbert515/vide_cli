import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/vide_colors.dart';
import '../../data/local/settings_storage.dart';
import '../../data/repositories/connection_repository.dart';
import '../../domain/models/server_connection.dart';
import 'connection_state.dart';

/// Screen for connecting to a Vide server.
class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _hostController = TextEditingController(text: 'localhost');
  final _portController = TextEditingController(text: '8080');
  final _formKey = GlobalKey<FormState>();
  bool _isAutoConnecting = false;
  String? _autoConnectError;

  @override
  void initState() {
    super.initState();
    _hostController.addListener(_onHostChanged);
    _portController.addListener(_onPortChanged);
    _attemptAutoConnect();
  }

  void _onHostChanged() {
    ref.read(connectionNotifierProvider.notifier).setHost(_hostController.text);
  }

  void _onPortChanged() {
    ref
        .read(connectionNotifierProvider.notifier)
        .setPortFromString(_portController.text);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _attemptAutoConnect() async {
    final settingsStorage = ref.read(settingsStorageProvider.notifier);
    final lastConnection = await settingsStorage.getLastConnection();

    if (lastConnection == null || !mounted) return;

    setState(() {
      _isAutoConnecting = true;
      _autoConnectError = null;
    });

    _hostController.text = lastConnection.host;
    _portController.text = lastConnection.port.toString();

    try {
      await ref
          .read(connectionRepositoryProvider.notifier)
          .connect(lastConnection);
      if (mounted) {
        context.go(AppRoutes.sessions);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAutoConnecting = false;
          _autoConnectError =
              'Could not connect to ${lastConnection.host}:${lastConnection.port}';
        });
      }
    }
  }

  Future<void> _connectToServer() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(connectionNotifierProvider.notifier);

    // Test connection first
    final success = await notifier.testConnection();
    if (!success || !mounted) return;

    // If test passed, connect
    final state = ref.read(connectionNotifierProvider);
    final connection = ServerConnection(
      host: state.host,
      port: state.port,
    );

    try {
      await ref.read(connectionRepositoryProvider.notifier).connect(connection);
      if (mounted) {
        context.go(AppRoutes.sessions);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isTesting = connectionState.status == ConnectionStatus.testing;

    if (_isAutoConnecting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.terminal_rounded,
                size: 80,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Connecting to saved server...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                // App logo/icon
                Icon(
                  Icons.terminal_rounded,
                  size: 80,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect to Server',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your Vide server details to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (_autoConnectError != null) ...[
                  const SizedBox(height: 16),
                  _AutoConnectErrorBanner(message: _autoConnectError!),
                ],
                const SizedBox(height: 48),
                // Host field
                TextFormField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: 'e.g. localhost, 192.168.1.100',
                    helperText: 'IP address or hostname (without http://)',
                    prefixIcon: Icon(Icons.computer_outlined),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  enabled: !isTesting,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Host is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Port field
                TextFormField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '8080',
                    prefixIcon: Icon(Icons.numbers_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  enabled: !isTesting,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Port is required';
                    }
                    final port = int.tryParse(value);
                    if (port == null || port < 1 || port > 65535) {
                      return 'Enter a valid port (1-65535)';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _connectToServer(),
                ),
                const SizedBox(height: 24),
                // Connection status indicator
                if (connectionState.status != ConnectionStatus.disconnected)
                  _ConnectionStatusChip(status: connectionState.status),
                if (connectionState.status != ConnectionStatus.disconnected)
                  const SizedBox(height: 24),
                // Single Connect button
                FilledButton.icon(
                  onPressed: isTesting ? null : _connectToServer,
                  icon: isTesting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.login_outlined),
                  label: Text(isTesting ? 'Connecting...' : 'Connect'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoConnectErrorBanner extends StatelessWidget {
  final String message;

  const _AutoConnectErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusChip extends StatelessWidget {
  final ConnectionStatus status;

  const _ConnectionStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    final (icon, label, color) = switch (status) {
      ConnectionStatus.disconnected => (
          Icons.cloud_off_outlined,
          'Disconnected',
          colorScheme.outline,
        ),
      ConnectionStatus.testing => (
          Icons.sync_outlined,
          'Testing...',
          colorScheme.primary,
        ),
      ConnectionStatus.connected => (
          Icons.check_circle_outline,
          'Connected',
          videColors.success,
        ),
      ConnectionStatus.error => (
          Icons.error_outline,
          'Connection failed',
          colorScheme.error,
        ),
    };

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
