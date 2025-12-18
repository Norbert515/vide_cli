import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/modules/agent_network/models/agent_metadata.dart';
import 'package:vide_cli/modules/agent_network/models/agent_status.dart';
import 'package:vide_cli/components/tool_invocations/todo_list_component.dart';
import 'package:vide_cli/components/enhanced_loading_indicator.dart';
import 'package:vide_cli/constants/text_opacity.dart';

/// Demo entry point for taking screenshots for the README.
/// Renders a static UI showcasing the main features of Vide CLI.
void main() async {
  await runApp(DemoApp());
}

class DemoApp extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return NoctermApp(
      title: 'Vide - AI Agent Network',
      child: Padding(
        padding: EdgeInsets.all(1),
        child: DemoPage(),
      ),
    );
  }
}

class DemoPage extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with goal
        Text(
          'Implement user authentication with JWT tokens',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Divider(),

        // Running agents bar
        _DemoAgentsBar(),

        // Scrollable content area
        Expanded(
          child: ListView(
            reverse: true,
            padding: EdgeInsets.all(1),
            children: [
              // Todo list (at top when reversed)
              TodoListComponent(
                todos: [
                  {'content': 'Research existing auth patterns', 'status': 'completed'},
                  {'content': 'Create JWT token service', 'status': 'completed'},
                  {'content': 'Implement token validation', 'status': 'completed'},
                  {'content': 'Add secure token storage', 'status': 'completed'},
                  {'content': 'Implement refresh token flow', 'status': 'in_progress'},
                  {'content': 'Add token rotation logic', 'status': 'pending'},
                  {'content': 'Write integration tests', 'status': 'pending'},
                ],
              ),

              // Messages in reverse order (bottom to top)
              _DemoAIResponseStreaming(),
              SizedBox(height: 1),
              _DemoToolInvocationsPhase3(),
              _DemoUserMessage('Can you also add refresh token support?'),
              SizedBox(height: 1),
              _DemoAIResponseImplementation(),
              _DemoToolInvocationsPhase2(),
              _DemoAIResponsePlan(),
              SizedBox(height: 1),
              _DemoToolInvocationsPhase1(),
              _DemoUserMessage('Add user authentication with JWT tokens to my Flutter app'),
            ],
          ),
        ),

        // Loading indicator
        EnhancedLoadingIndicator(
          responseStartTime: DateTime.now().subtract(Duration(seconds: 8)),
          outputTokens: 2341,
          dynamicWords: [
            'Implementing refresh tokens...',
            'Writing secure code...',
            'Validating token flow...',
          ],
        ),

        // Input text field at the bottom
        _DemoInputField(),
      ],
    );
  }
}

/// User message component - matches real Vide styling
class _DemoUserMessage extends StatelessComponent {
  final String message;

  _DemoUserMessage(this.message);

  @override
  Component build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 1),
      child: Text('> $message', style: TextStyle(color: Colors.white)),
    );
  }
}

/// Demo agents bar showing multiple agents in different states
class _DemoAgentsBar extends StatefulComponent {
  @override
  State<_DemoAgentsBar> createState() => _DemoAgentsBarState();
}

class _DemoAgentsBarState extends State<_DemoAgentsBar> {
  static const _spinnerFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  int _spinnerIndex = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: 100), (_) {
      setState(() {
        _spinnerIndex = (_spinnerIndex + 1) % _spinnerFrames.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final agents = [
      AgentMetadata(
        id: 'main-001',
        name: 'Main',
        type: 'main',
        status: AgentStatus.working,
        taskName: 'Implement user authentication',
        createdAt: DateTime.now().subtract(Duration(minutes: 5)),
      ),
      AgentMetadata(
        id: 'research-002',
        name: 'Auth Research',
        type: 'contextCollection',
        status: AgentStatus.idle,
        taskName: 'Research complete',
        createdAt: DateTime.now().subtract(Duration(minutes: 3)),
      ),
      AgentMetadata(
        id: 'jwt-003',
        name: 'JWT Service',
        type: 'implementation',
        status: AgentStatus.working,
        taskName: 'Implementing refresh tokens',
        createdAt: DateTime.now().subtract(Duration(minutes: 1)),
      ),
    ];

    return Row(
      children: [
        for (final agent in agents) _buildAgentItem(agent),
      ],
    );
  }

  Component _buildAgentItem(AgentMetadata agent) {
    final statusIndicator = _getStatusIndicator(agent.status);
    final indicatorColor = _getIndicatorColor(agent.status);
    final indicatorTextColor = _getIndicatorTextColor(agent.status);
    final displayName = agent.taskName != null && agent.taskName!.isNotEmpty
        ? '${agent.name} - ${agent.taskName}'
        : agent.name;

    return Padding(
      padding: EdgeInsets.only(right: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: indicatorColor),
            child: Text(statusIndicator, style: TextStyle(color: indicatorTextColor)),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: Colors.grey),
            child: Text(displayName, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getStatusIndicator(AgentStatus status) {
    return switch (status) {
      AgentStatus.working => _spinnerFrames[_spinnerIndex],
      AgentStatus.waitingForAgent => '…',
      AgentStatus.waitingForUser => '?',
      AgentStatus.idle => '✓',
    };
  }

  Color _getIndicatorColor(AgentStatus status) {
    return switch (status) {
      AgentStatus.working => Colors.cyan,
      AgentStatus.waitingForAgent => Colors.yellow,
      AgentStatus.waitingForUser => Colors.magenta,
      AgentStatus.idle => Colors.green,
    };
  }

  Color _getIndicatorTextColor(AgentStatus status) {
    return switch (status) {
      AgentStatus.waitingForAgent => Colors.black,
      _ => Colors.white,
    };
  }
}

/// Phase 1: Initial research tool invocations
class _DemoToolInvocationsPhase1 extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Glob tool - searching for auth files
        _buildToolInvocation(
          toolName: 'Glob',
          params: 'pattern: **/auth*.dart',
          isComplete: true,
          isError: false,
          resultPreview: '3 files found',
        ),

        // Read tool - auth_service.dart
        _buildToolInvocation(
          toolName: 'Read',
          params: 'file_path: lib/services/auth_service.dart',
          isComplete: true,
          isError: false,
        ),

        // Read tool - user_model.dart
        _buildToolInvocation(
          toolName: 'Read',
          params: 'file_path: lib/models/user_model.dart',
          isComplete: true,
          isError: false,
        ),
      ],
    );
  }

  Component _buildToolInvocation({
    required String toolName,
    required String params,
    required bool isComplete,
    required bool isError,
    String? resultPreview,
  }) {
    final Color statusColor;
    if (!isComplete) {
      statusColor = Colors.yellow;
    } else if (isError) {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.green;
    }

    return Container(
      padding: EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('●', style: TextStyle(color: statusColor)),
              SizedBox(width: 1),
              Text(toolName, style: TextStyle(color: Colors.white)),
              Text(
                '($params)',
                style: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
              ),
            ],
          ),
          if (resultPreview != null)
            Container(
              padding: EdgeInsets.only(left: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⎿  ', style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary))),
                  Text(
                    resultPreview,
                    style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// AI response explaining the plan - uses MarkdownText like real Vide
class _DemoAIResponsePlan extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return MarkdownText(
      "I found your existing auth structure. I'll create a JWT service that integrates with your AuthService.",
    );
  }
}

/// Phase 2: Implementation tool invocations
class _DemoToolInvocationsPhase2 extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Edit tool - jwt_service.dart
        _buildToolInvocation(
          toolName: 'Edit',
          params: 'file_path: lib/services/jwt_service.dart',
          isComplete: true,
          isError: false,
          resultPreview: 'Added generateToken method (28 lines)',
        ),

        // Edit tool - auth_controller.dart
        _buildToolInvocation(
          toolName: 'Edit',
          params: 'file_path: lib/controllers/auth_controller.dart',
          isComplete: true,
          isError: false,
          resultPreview: 'Integrated JWT validation',
        ),

        // Write tool - token_storage.dart
        _buildToolInvocation(
          toolName: 'Write',
          params: 'file_path: lib/services/token_storage.dart',
          isComplete: true,
          isError: false,
          resultPreview: 'Created secure storage service (45 lines)',
        ),

        // Bash tool - running tests
        _buildToolInvocation(
          toolName: 'Bash',
          params: 'command: dart test test/auth_test.dart',
          isComplete: true,
          isError: false,
          resultPreview: 'All 12 tests passed!',
        ),
      ],
    );
  }

  Component _buildToolInvocation({
    required String toolName,
    required String params,
    required bool isComplete,
    required bool isError,
    String? resultPreview,
  }) {
    final Color statusColor;
    if (!isComplete) {
      statusColor = Colors.yellow;
    } else if (isError) {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.green;
    }

    return Container(
      padding: EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('●', style: TextStyle(color: statusColor)),
              SizedBox(width: 1),
              Text(toolName, style: TextStyle(color: Colors.white)),
              Text(
                '($params)',
                style: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
              ),
            ],
          ),
          if (resultPreview != null)
            Container(
              padding: EdgeInsets.only(left: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⎿  ', style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary))),
                  Text(
                    resultPreview,
                    style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// AI response with implementation details and code example - uses MarkdownText
class _DemoAIResponseImplementation extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return MarkdownText(
      """I've implemented JWT authentication with the following features:

- Token generation with 24-hour expiry
- HMAC-SHA256 signature verification
- Secure token storage using flutter_secure_storage

Usage example:

```dart
final token = await jwtService.generateToken(user);
await tokenStorage.saveToken(token);
```

All tests pass and the implementation follows your existing patterns.""",
    );
  }
}

/// Phase 3: Refresh token tool invocations
class _DemoToolInvocationsPhase3 extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Edit tool - adding refresh token logic
        _buildToolInvocation(
          toolName: 'Edit',
          params: 'file_path: lib/services/jwt_service.dart',
          isComplete: true,
          isError: false,
          resultPreview: 'Added refreshToken method',
        ),

        // Bash tool - running analyzer
        _buildToolInvocation(
          toolName: 'Bash',
          params: 'command: dart analyze lib/',
          isComplete: true,
          isError: false,
          resultPreview: 'No issues found!',
        ),
      ],
    );
  }

  Component _buildToolInvocation({
    required String toolName,
    required String params,
    required bool isComplete,
    required bool isError,
    String? resultPreview,
  }) {
    final Color statusColor;
    if (!isComplete) {
      statusColor = Colors.yellow;
    } else if (isError) {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.green;
    }

    return Container(
      padding: EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('●', style: TextStyle(color: statusColor)),
              SizedBox(width: 1),
              Text(toolName, style: TextStyle(color: Colors.white)),
              Text(
                '($params)',
                style: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
              ),
            ],
          ),
          if (resultPreview != null)
            Container(
              padding: EdgeInsets.only(left: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⎿  ', style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary))),
                  Text(
                    resultPreview,
                    style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Partial AI response showing streaming - uses MarkdownText
class _DemoAIResponseStreaming extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return MarkdownText(
      "I've added refresh token support with automatic rotation. The refresh token has a 7-day expiry and will...",
    );
  }
}

/// Static input field for demo
class _DemoInputField extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(border: BoxBorder.all(color: Colors.grey)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('>', style: TextStyle(color: Colors.white)),
          SizedBox(width: 1),
          Expanded(
            child: Text(
              'Type a message...',
              style: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
            ),
          ),
        ],
      ),
    );
  }
}
