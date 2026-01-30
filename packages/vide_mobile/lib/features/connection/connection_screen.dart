import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
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

  @override
  void initState() {
    super.initState();
    _hostController.addListener(_onHostChanged);
    _portController.addListener(_onPortChanged);
  }

  void _onHostChanged() {
    ref.read(connectionNotifierProvider.notifier).setHost(_hostController.text);
  }

  void _onPortChanged() {
    ref.read(connectionNotifierProvider.notifier).setPortFromString(_portController.text);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(connectionNotifierProvider.notifier).testConnection();

    if (mounted && !success) {
      final error = ref.read(connectionNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Connection failed'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _connect() {
    final state = ref.read(connectionNotifierProvider);
    if (state.status == ConnectionStatus.connected) {
      context.push(AppRoutes.sessions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isTesting = connectionState.status == ConnectionStatus.testing;
    final isConnected = connectionState.status == ConnectionStatus.connected;

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
                  onFieldSubmitted: (_) => _testConnection(),
                ),
                const SizedBox(height: 24),
                // Connection status indicator
                if (connectionState.status != ConnectionStatus.disconnected)
                  _ConnectionStatusChip(status: connectionState.status),
                const SizedBox(height: 24),
                // Test Connection button
                OutlinedButton.icon(
                  onPressed: isTesting ? null : _testConnection,
                  icon: isTesting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.wifi_find_outlined),
                  label: Text(isTesting ? 'Testing...' : 'Test Connection'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 12),
                // Connect button
                FilledButton.icon(
                  onPressed: isConnected ? _connect : null,
                  icon: const Icon(Icons.login_outlined),
                  label: const Text('Connect'),
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

class _ConnectionStatusChip extends StatelessWidget {
  final ConnectionStatus status;

  const _ConnectionStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          Colors.green,
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
