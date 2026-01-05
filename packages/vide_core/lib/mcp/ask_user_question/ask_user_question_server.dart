import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:sentry/sentry.dart';
import 'package:riverpod/riverpod.dart';
import '../../../models/agent_id.dart';
import 'ask_user_question_service.dart';
import 'ask_user_question_types.dart';

final askUserQuestionServerProvider =
    Provider.family<AskUserQuestionServer, AgentId>((ref, agentId) {
      return AskUserQuestionServer(
        callerAgentId: agentId,
        service: ref.watch(askUserQuestionServiceProvider),
      );
    });

/// MCP server providing AskUserQuestion tool
///
/// This provides a structured way for agents to ask users multiple-choice questions.
/// The tool blocks until the user responds via the UI.
class AskUserQuestionServer extends McpServerBase {
  static const String serverName = 'vide-ask-user-question';

  final AgentId callerAgentId;
  final AskUserQuestionService _service;

  AskUserQuestionServer({
    required this.callerAgentId,
    required AskUserQuestionService service,
  }) : _service = service,
       super(name: serverName, version: '1.0.0');

  @override
  List<String> get toolNames => ['askUserQuestion'];

  @override
  void registerTools(McpServer server) {
    server.tool(
      'askUserQuestion',
      description:
          '''Ask the user one or more structured multiple-choice questions.

Use this tool when you need clear, unambiguous decisions from the user:
- Choosing between 2-4 implementation approaches
- Selecting preferences (database, framework, etc.)
- Making architectural decisions
- Any situation with distinct options

The tool will display a dialog and wait for user response.
Returns a map of question text -> selected answer(s).

For open-ended questions, just ask in regular text instead.''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'questions': {
            'type': 'array',
            'description': 'List of questions to ask (1-4 questions)',
            'items': {
              'type': 'object',
              'properties': {
                'question': {
                  'type': 'string',
                  'description': 'The question text',
                },
                'header': {
                  'type': 'string',
                  'description': 'Optional header/category for the question',
                },
                'multiSelect': {
                  'type': 'boolean',
                  'description':
                      'If true, user can select multiple options. Default: false',
                },
                'options': {
                  'type': 'array',
                  'description':
                      'List of options (2-4 options). Put recommended option first.',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'label': {
                        'type': 'string',
                        'description':
                            'Short option label (1-5 words). Add "(Recommended)" for preferred option.',
                      },
                      'description': {
                        'type': 'string',
                        'description': 'Explanation of what this option means',
                      },
                    },
                    'required': ['label', 'description'],
                  },
                },
              },
              'required': ['question', 'options'],
            },
          },
        },
        required: ['questions'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final questionsJson = args['questions'] as List<dynamic>?;
        if (questionsJson == null || questionsJson.isEmpty) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No questions provided')],
          );
        }

        if (questionsJson.length > 4) {
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: Maximum 4 questions allowed per call'),
            ],
          );
        }

        try {
          // Parse questions
          final questions = questionsJson.map((q) {
            final qMap = q as Map<String, dynamic>;
            return AskUserQuestion.fromJson(qMap);
          }).toList();

          // Validate options count
          for (final q in questions) {
            if (q.options.length < 2) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(
                    text: 'Error: Each question must have at least 2 options',
                  ),
                ],
              );
            }
            if (q.options.length > 4) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(
                    text: 'Error: Each question can have at most 4 options',
                  ),
                ],
              );
            }
          }

          // Ask the user via the service (blocks until UI responds)
          final answers = await _service.askQuestions(questions);

          // Return JSON response for easy parsing by UI renderer
          final jsonResponse = <String, dynamic>{};
          for (final entry in answers.entries) {
            jsonResponse[entry.key] = entry.value;
          }

          return CallToolResult.fromContent(
            content: [TextContent(text: jsonEncode(jsonResponse))],
          );
        } catch (e, stackTrace) {
          await Sentry.configureScope((scope) {
            scope.setTag('mcp_server', serverName);
            scope.setTag('mcp_tool', 'askUserQuestion');
            scope.setContexts('mcp_context', {
              'caller_agent_id': callerAgentId.toString(),
            });
          });
          await Sentry.captureException(e, stackTrace: stackTrace);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error asking user: $e')],
          );
        }
      },
    );
  }
}
