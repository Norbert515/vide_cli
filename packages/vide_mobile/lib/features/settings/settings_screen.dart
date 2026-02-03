import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vide_colors.dart';

/// Settings screen for the app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // Connection section
          const _SectionHeader(title: 'Connection'),
          _SettingsTile(
            icon: Icons.history,
            title: 'Connection History',
            subtitle: 'View and manage saved connections',
            onTap: () {
              _showConnectionHistory(context);
            },
          ),
          _SettingsTile(
            icon: Icons.dns_outlined,
            title: 'Default Server',
            subtitle: 'Set your default Vide server',
            onTap: () {
              // TODO: Implement default server selection
            },
          ),
          const Divider(height: 32),
          // Appearance section
          const _SectionHeader(title: 'Appearance'),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            subtitle: 'System default',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showThemeSelector(context);
            },
          ),
          const Divider(height: 32),
          // Data section
          const _SectionHeader(title: 'Data'),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: 'Clear Data',
            subtitle: 'Clear all local data and settings',
            iconColor: videColors.error,
            onTap: () {
              _showClearDataConfirmation(context);
            },
          ),
          const Divider(height: 32),
          // About section
          const _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About Vide Mobile',
            subtitle: 'Version 1.0.0',
            onTap: () {
              _showAboutDialog(context);
            },
          ),
          _SettingsTile(
            icon: Icons.code,
            title: 'Source Code',
            subtitle: 'View on GitHub',
            onTap: () {
              // TODO: Open GitHub URL
            },
          ),
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Report an Issue',
            subtitle: 'Help us improve',
            onTap: () {
              // TODO: Open issue tracker
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showConnectionHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const _ConnectionHistorySheet(),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ThemeSelectorDialog(),
    );
  }

  void _showClearDataConfirmation(BuildContext context) {
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
              // TODO: Clear data
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: videColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? videColors.accent).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 22,
          color: iconColor ?? videColors.accent,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _ConnectionHistorySheet extends StatelessWidget {
  const _ConnectionHistorySheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Placeholder - in real implementation, this would read from shared preferences
    final connections = <_ConnectionItem>[
      _ConnectionItem('localhost:8080', DateTime.now().subtract(const Duration(hours: 1))),
      _ConnectionItem('192.168.1.100:8080', DateTime.now().subtract(const Duration(days: 1))),
      _ConnectionItem('vide.example.com:443', DateTime.now().subtract(const Duration(days: 7))),
    ];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Connection History',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // TODO: Clear history
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          const Divider(),
          if (connections.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No connection history'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              itemCount: connections.length,
              itemBuilder: (context, index) {
                final conn = connections[index];
                return ListTile(
                  leading: const Icon(Icons.computer_outlined),
                  title: Text(conn.address),
                  subtitle: Text(_formatDate(conn.lastUsed)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      // TODO: Remove from history
                    },
                  ),
                  onTap: () {
                    // TODO: Use this connection
                    Navigator.pop(context);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

class _ConnectionItem {
  final String address;
  final DateTime lastUsed;

  _ConnectionItem(this.address, this.lastUsed);
}

class _ThemeSelectorDialog extends StatelessWidget {
  const _ThemeSelectorDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Theme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('System'),
            subtitle: const Text('Follow system settings'),
            value: ThemeMode.system,
            groupValue: ThemeMode.system, // TODO: Get from provider
            onChanged: (value) {
              // TODO: Update theme
              Navigator.pop(context);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: ThemeMode.system,
            onChanged: (value) {
              Navigator.pop(context);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: ThemeMode.system,
            onChanged: (value) {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
