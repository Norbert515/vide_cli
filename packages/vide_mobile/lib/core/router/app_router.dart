import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:vide_client/vide_client.dart';

import '../../features/chat/chat_screen.dart';
import '../../features/chat/widgets/tool_card.dart';
import '../../features/connection/connection_screen.dart';
import '../../features/session/session_creation_screen.dart';
import '../../features/sessions/sessions_list_screen.dart';
import '../../features/settings/admin_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/title/title_screen.dart';

part 'app_router.g.dart';

/// Route paths for the app
abstract class AppRoutes {
  static const connection = '/';
  static const sessions = '/sessions';
  static const newSession = '/session/new';
  static const session = '/session/:id';
  static const settings = '/settings';
  static const admin = '/admin';
  static const title = '/title';
  static const toolDetail = '/session/:id/tool';

  static String sessionPath(String id) => '/session/$id';
  static String toolDetailPath(String sessionId) => '/session/$sessionId/tool';
}

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.connection,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.connection,
        name: 'connection',
        builder: (context, state) => const ConnectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.sessions,
        name: 'sessions',
        builder: (context, state) => const SessionsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.newSession,
        name: 'newSession',
        builder: (context, state) => const SessionCreationScreen(),
      ),
      GoRoute(
        path: AppRoutes.session,
        name: 'session',
        builder: (context, state) {
          final sessionId = state.pathParameters['id']!;
          return ChatScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: AppRoutes.toolDetail,
        name: 'toolDetail',
        builder: (context, state) {
          final tool = state.extra! as ToolContent;
          return ToolDetailScreen(tool: tool);
        },
      ),
      GoRoute(
        path: AppRoutes.title,
        name: 'title',
        builder: (context, state) => const TitleScreen(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        name: 'admin',
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
}

class ErrorScreen extends StatelessWidget {
  final Exception? error;

  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.connection),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
