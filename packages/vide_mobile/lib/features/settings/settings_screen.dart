import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/vide_colors.dart';
import '../../data/local/settings_storage.dart';
import '../../data/repositories/connection_repository.dart';
import 'widgets/settings_tile.dart';

/// Settings screen for the app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;
    final connectionState = ref.watch(connectionRepositoryProvider);

    final serverSubtitle = connectionState.isConnected &&
            connectionState.connection != null
        ? '${connectionState.connection!.host}:${connectionState.connection!.port}'
        : 'Not connected';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.sessions),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // Connection section
          const SectionHeader(title: 'Connection'),
          SettingsTile(
            icon: Icons.dns_outlined,
            title: 'Current Server',
            subtitle: serverSubtitle,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.go(AppRoutes.connection);
            },
          ),
          if (connectionState.isConnected)
            SettingsTile(
              icon: Icons.link_off,
              title: 'Disconnect',
              subtitle: 'Disconnect and return to setup',
              onTap: () {
                ref.read(connectionRepositoryProvider.notifier).disconnect();
                ref.read(settingsStorageProvider.notifier).clear();
                ref
                    .read(themeModeNotifierProvider.notifier)
                    .setThemeMode(ThemeMode.system);
                context.go(AppRoutes.connection);
              },
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
              ref.read(connectionRepositoryProvider.notifier).disconnect();
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
