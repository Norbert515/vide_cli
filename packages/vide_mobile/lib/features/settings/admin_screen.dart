import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import 'widgets/settings_tile.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Admin Panel'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const SectionHeader(title: 'Visual Previews'),
          SettingsTile(
            icon: Icons.blur_circular,
            title: 'Vortex Title Screen',
            subtitle: 'Animated vortex background with VIDE logo',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.title),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
