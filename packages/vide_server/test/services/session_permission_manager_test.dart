import 'dart:async';

import 'package:test/test.dart';
import 'package:vide_server/services/server_config.dart';
import 'package:vide_server/services/session_permission_manager.dart';

void main() {
  group('SessionPermissionManager', () {
    late SessionPermissionManager manager;

    setUp(() {
      // Create a fresh manager for each test
      manager = SessionPermissionManager.instance;
      // Initialize with short timeout for testing
      manager.initialize(
        ServerConfig(permissionTimeoutSeconds: 1, autoApproveAll: false),
      );
    });

    tearDown(() {
      // Clean up any registered sessions
      manager.unregisterSession('test-session');
      manager.unregisterSession('session-1');
      manager.unregisterSession('session-2');
    });

    group('session registration', () {
      test('registerSession adds session to manager', () {
        expect(manager.sessionCount, 0);

        manager.registerSession(
          sessionId: 'test-session',
          onPermissionRequest:
              (_, __, ___, ____, _____, ______, _______, ________) {},
          onPermissionTimeout: (_, __, ___, ____, _____, ______, _______) {},
        );

        expect(manager.sessionCount, 1);
      });

      test('unregisterSession removes session', () {
        manager.registerSession(
          sessionId: 'test-session',
          onPermissionRequest:
              (_, __, ___, ____, _____, ______, _______, ________) {},
          onPermissionTimeout: (_, __, ___, ____, _____, ______, _______) {},
        );
        expect(manager.sessionCount, 1);

        manager.unregisterSession('test-session');
        expect(manager.sessionCount, 0);
      });

      test(
        'unregisterSession cancels pending requests for that session',
        () async {
          final requestReceived = Completer<void>();

          manager.registerSession(
            sessionId: 'test-session',
            onPermissionRequest:
                (_, __, ___, ____, _____, ______, _______, ________) {
                  requestReceived.complete();
                },
            onPermissionTimeout: (_, __, ___, ____, _____, ______, _______) {},
          );

          // Start a permission request
          final resultFuture = manager.requestPermission(
            sessionId: 'test-session',
            toolName: 'Bash',
            toolInput: {'command': 'rm -rf foo'},
            agentId: 'agent-1',
            agentType: 'main',
          );

          await requestReceived.future;
          expect(manager.pendingCount, 1);

          // Unregister session - should cancel pending request
          manager.unregisterSession('test-session');
          expect(manager.pendingCount, 0);

          // Request should complete with deny
          final result = await resultFuture;
          expect(result, isA<SessionPermissionDeny>());
          expect(
            (result as SessionPermissionDeny).message,
            'Request cancelled',
          );
        },
      );
    });

    group('requestPermission', () {
      test('returns deny when no session registered', () async {
        final result = await manager.requestPermission(
          sessionId: 'unregistered-session',
          toolName: 'Bash',
          toolInput: {'command': 'ls'},
          agentId: 'agent-1',
          agentType: 'main',
        );

        expect(result, isA<SessionPermissionDeny>());
        expect(
          (result as SessionPermissionDeny).message,
          contains('No active client connection'),
        );
      });

      test('calls onPermissionRequest callback', () async {
        String? capturedRequestId;
        String? capturedToolName;
        Map<String, dynamic>? capturedToolInput;

        manager.registerSession(
          sessionId: 'test-session',
          onPermissionRequest:
              (
                requestId,
                toolName,
                toolInput,
                inferredPattern,
                agentId,
                agentType,
                agentName,
                taskName,
              ) {
                capturedRequestId = requestId;
                capturedToolName = toolName;
                capturedToolInput = toolInput;
                // Immediately respond
                manager.handlePermissionResponse(
                  requestId: requestId,
                  allow: true,
                );
              },
          onPermissionTimeout: (_, __, ___, ____, _____, ______, _______) {},
        );

        final result = await manager.requestPermission(
          sessionId: 'test-session',
          toolName: 'Bash',
          toolInput: {'command': 'ls'},
          agentId: 'agent-1',
          agentType: 'main',
        );

        expect(capturedRequestId, isNotNull);
        expect(capturedToolName, 'Bash');
        expect(capturedToolInput, {'command': 'ls'});
        expect(result, isA<SessionPermissionAllow>());
      });

      test('returns allow when auto-approve is enabled', () async {
        manager.initialize(
          ServerConfig(permissionTimeoutSeconds: 1, autoApproveAll: true),
        );

        // No session registered, but auto-approve should work
        final result = await manager.requestPermission(
          sessionId: 'any-session',
          toolName: 'Bash',
          toolInput: {'command': 'rm -rf /'},
          agentId: 'agent-1',
          agentType: 'main',
        );

        expect(result, isA<SessionPermissionAllow>());
      });
    });

    group('handlePermissionResponse', () {
      test('allow response completes request with allow', () async {
        final requestReceived = Completer<String>();

        manager.registerSession(
          sessionId: 'test-session',
          onPermissionRequest:
              (requestId, _, __, ___, ____, _____, ______, _______) {
                requestReceived.complete(requestId);
              },
          onPermissionTimeout: (_, __, ___, ____, _____, ______, _______) {},
        );

        final resultFuture = manager.requestPermission(
          sessionId: 'test-session',
          toolName: 'Write',
          toolInput: {'file_path': '/test.txt'},
          agentId: 'agent-1',
          agentType: 'main',
        );

        final requestId = await requestReceived.future;

        final handled = manager.handlePermissionResponse(
          requestId: requestId,
          allow: true,
        );

        expect(handled, true);

        final result = await resultFuture;
        expect(result, isA<SessionPermissionAllow>());
      });

      test('deny response completes request with deny', () async {
        final requestReceived = Completer<String>();

        manager.registerSession(
          sessionId: 'test-session',
          onPermissionRequest:
              (requestId, _, __, ___, ____, _____, ______, _______) {
                requestReceived.complete(requestId);
              },
          onPermissionTimeout: (_, __, ___, ____, _____, ______, _______) {},
        );

        final resultFuture = manager.requestPermission(
          sessionId: 'test-session',
          toolName: 'Bash',
          toolInput: {'command': 'rm -rf /'},
          agentId: 'agent-1',
          agentType: 'main',
        );

        final requestId = await requestReceived.future;

        final handled = manager.handlePermissionResponse(
          requestId: requestId,
          allow: false,
          message: 'User declined',
        );

        expect(handled, true);

        final result = await resultFuture;
        expect(result, isA<SessionPermissionDeny>());
        expect((result as SessionPermissionDeny).message, 'User declined');
      });

      test('returns false for unknown request ID', () {
        final handled = manager.handlePermissionResponse(
          requestId: 'unknown-request-id',
          allow: true,
        );

        expect(handled, false);
      });
    });

    group('timeout', () {
      test('request times out and calls onPermissionTimeout', () async {
        String? timedOutRequestId;

        manager.registerSession(
          sessionId: 'test-session',
          onPermissionRequest:
              (_, __, ___, ____, _____, ______, _______, ________) {},
          onPermissionTimeout:
              (requestId, toolName, timeoutSeconds, _, __, ___, ____) {
                timedOutRequestId = requestId;
              },
        );

        final result = await manager.requestPermission(
          sessionId: 'test-session',
          toolName: 'Bash',
          toolInput: {'command': 'dangerous'},
          agentId: 'agent-1',
          agentType: 'main',
        );

        expect(result, isA<SessionPermissionDeny>());
        expect(
          (result as SessionPermissionDeny).message,
          contains('timed out'),
        );
        expect(timedOutRequestId, isNotNull);
      });
    });
  });
}
