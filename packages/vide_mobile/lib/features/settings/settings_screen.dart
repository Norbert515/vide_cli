import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/vide_colors.dart';
import '../../data/local/settings_storage.dart';
import '../../data/repositories/server_registry.dart';
import '../../domain/models/server_connection.dart';
import 'widgets/settings_tile.dart';

/// Settings screen for the app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final registryState = ref.watch(serverRegistryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (registryState.isEmpty) {
              context.go(AppRoutes.connection);
            } else {
              context.go(AppRoutes.sessions);
            }
          },
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // Servers section
          const SectionHeader(title: 'Servers'),
          ...registryState.entries.map((entry) {
            final server = entry.value;
            final statusColor = switch (server.status) {
              ServerHealthStatus.connected => videColors.success,
              ServerHealthStatus.connecting => videColors.warning,
              ServerHealthStatus.error => videColors.error,
              ServerHealthStatus.disconnected =>
                Theme.of(context).colorScheme.outline,
            };
            final statusLabel = switch (server.status) {
              ServerHealthStatus.connected => 'Connected',
              ServerHealthStatus.connecting => 'Connecting...',
              ServerHealthStatus.error =>
                server.errorMessage ?? 'Error',
              ServerHealthStatus.disconnected => 'Disconnected',
            };

            return SettingsTile(
              icon: Icons.dns_outlined,
              title: server.connection.displayName,
              subtitle:
                  '${server.connection.host}:${server.connection.port} · $statusLabel',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () =>
                  _showServerOptions(context, ref, entry.key, server),
            );
          }),
          SettingsTile(
            icon: Icons.add,
            title: 'Add Server',
            subtitle: 'Connect to another Vide server',
            onTap: () => context.push(AppRoutes.connection),
          ),
          const Divider(height: 32),
          // Appearance section
          const SectionHeader(title: 'Appearance'),
          SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            subtitle: switch (ref.watch(themeModeNotifierProvider)) {
              ThemeMode.system => 'System default',
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
            },
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showThemeSelector(context);
            },
          ),
          const Divider(height: 32),
          // Data section
          const SectionHeader(title: 'Data'),
          SettingsTile(
            icon: Icons.delete_outline,
            title: 'Clear Data',
            subtitle: 'Clear all local data and settings',
            iconColor: videColors.error,
            onTap: () {
              _showClearDataConfirmation(context, ref);
            },
          ),
          const Divider(height: 32),
          // About section
          const SectionHeader(title: 'About'),
          SettingsTile(
            icon: Icons.info_outline,
            title: 'About Vide Mobile',
            subtitle: 'Version 1.0.0',
            onTap: () {
              _showAboutDialog(context);
            },
          ),
          SettingsTile(
            icon: Icons.code,
            title: 'Source Code',
            subtitle: 'View on GitHub',
            onTap: () {
              // TODO: Open GitHub URL
            },
          ),
          SettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Report an Issue',
            subtitle: 'Help us improve',
            onTap: () {
              // TODO: Open issue tracker
            },
          ),
          const Divider(height: 32),
          // Developer section
          const SectionHeader(title: 'Developer'),
          SettingsTile(
            icon: Icons.build_outlined,
            title: 'Admin Panel',
            subtitle: 'Visual previews and developer tools',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push(AppRoutes.admin);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showServerOptions(
    BuildContext context,
    WidgetRef ref,
    String serverId,
    ServerEntry server,
  ) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                server.status == ServerHealthStatus.connected
                    ? Icons.link_off
                    : Icons.link,
              ),
              title: Text(
                server.status == ServerHealthStatus.connected
                    ? 'Disconnect'
                    : 'Connect',
              ),
              onTap: () {
                Navigator.pop(context);
                final registry = ref.read(serverRegistryProvider.notifier);
                if (server.status == ServerHealthStatus.connected) {
                  registry.disconnectServer(serverId);
                } else {
                  registry.connectServer(serverId);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Connection'),
              onTap: () {
                Navigator.pop(context);
                _showEditServer(context, ref, serverId, server);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: videColors.error),
              title: Text(
                'Remove',
                style: TextStyle(color: videColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveServer(context, ref, serverId, server);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServer(
    BuildContext context,
    WidgetRef ref,
    String serverId,
    ServerEntry server,
  ) {
    final nameController =
        TextEditingController(text: server.connection.name ?? '');
    final hostController =
        TextEditingController(text: server.connection.host);
    final portController =
        TextEditingController(text: server.connection.port.toString());

    void save() {
      final name = nameController.text.trim();
      final host = hostController.text.trim();
      final port = int.tryParse(portController.text.trim());

      if (host.isEmpty || port == null) return;

      final registry = ref.read(serverRegistryProvider.notifier);

      // Disconnect first if connection details changed
      final connectionChanged = host != server.connection.host ||
          port != server.connection.port;
      if (connectionChanged &&
          server.status == ServerHealthStatus.connected) {
        registry.disconnectServer(serverId);
      }

      registry.updateServer(
        server.connection.copyWith(
          name: name.isEmpty ? null : name,
          host: host,
          port: port,
        ),
      );

      Navigator.pop(context);

      // Reconnect with new details
      if (connectionChanged) {
        registry.connectServer(serverId);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'My Server',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hostController,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: '192.168.1.100',
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '8080',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => save(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveServer(
    BuildContext context,
    WidgetRef ref,
    String serverId,
    ServerEntry server,
  ) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Server?'),
        content: Text(
          'Remove "${server.connection.displayName}" from your servers?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(serverRegistryProvider.notifier).removeServer(serverId);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: videColors.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ThemeSelectorDialog(),
    );
  }

  void _showClearDataConfirmation(BuildContext context, WidgetRef ref) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will delete all saved connections, settings, and session data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(serverRegistryProvider.notifier).disconnectAll();
              ref.read(settingsStorageProvider.notifier).clear();
              ref
                  .read(themeModeNotifierProvider.notifier)
                  .setThemeMode(ThemeMode.system);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data cleared')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: videColors.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Vide Mobile',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.terminal_rounded,
        size: 48,
        color: Theme.of(context).extension<VideThemeColors>()!.accent,
      ),
      children: [
        const Text(
          'A mobile client for connecting to Vide servers and managing AI-powered development sessions.',
        ),
      ],
    );
  }
}

class _ThemeSelectorDialog extends ConsumerWidget {
  const _ThemeSelectorDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeNotifierProvider);

    return AlertDialog(
      title: const Text('Choose Theme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('System'),
            subtitle: const Text('Follow system settings'),
            value: ThemeMode.system,
            groupValue: currentMode,
            onChanged: (value) {
              ref.read(themeModeNotifierProvider.notifier).setThemeMode(value!);
              Navigator.pop(context);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: currentMode,
            onChanged: (value) {
              ref.read(themeModeNotifierProvider.notifier).setThemeMode(value!);
              Navigator.pop(context);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: currentMode,
            onChanged: (value) {
              ref.read(themeModeNotifierProvider.notifier).setThemeMode(value!);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
