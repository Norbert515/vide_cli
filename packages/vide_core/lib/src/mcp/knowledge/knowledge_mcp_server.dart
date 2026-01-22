import 'dart:convert';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:riverpod/riverpod.dart';
import '../../models/agent_id.dart';
import 'knowledge_service.dart';

/// Parameters for creating a knowledge server instance.
class KnowledgeServerParams {
  final AgentId agentId;
  final String projectPath;

  KnowledgeServerParams({
    required this.agentId,
    required this.projectPath,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeServerParams &&
          runtimeType == other.runtimeType &&
          agentId == agentId &&
          projectPath == projectPath;

  @override
  int get hashCode => agentId.hashCode ^ projectPath.hashCode;
}

final knowledgeServerProvider =
    Provider.family<KnowledgeMcpServer, KnowledgeServerParams>((ref, params) {
  return KnowledgeMcpServer(
    callerAgentId: params.agentId,
    projectPath: params.projectPath,
  );
});

/// MCP server for knowledge base operations.
///
/// Provides tools for reading and writing knowledge documents stored in
/// `.claude/knowledge/`. Supports hierarchical scoping (global, team, agent)
/// and search capabilities.
class KnowledgeMcpServer extends McpServerBase {
  static const String serverName = 'vide-knowledge';

  final AgentId callerAgentId;
  final KnowledgeService _service;

  KnowledgeMcpServer({
    required this.callerAgentId,
    required String projectPath,
  })  : _service = KnowledgeService(projectPath: projectPath),
        super(name: serverName, version: '1.0.0');

  @override
  List<String> get toolNames => [
        'getKnowledgeIndex',
        'getKnowledgeSummary',
        'readKnowledge',
        'writeKnowledge',
        'searchKnowledge',
        'listKnowledge',
      ];

  @override
  void registerTools(McpServer server) {
    _registerGetKnowledgeIndex(server);
    _registerGetKnowledgeSummary(server);
    _registerReadKnowledge(server);
    _registerWriteKnowledge(server);
    _registerSearchKnowledge(server);
    _registerListKnowledge(server);
  }

  void _registerGetKnowledgeIndex(McpServer server) {
    server.tool(
      'getKnowledgeIndex',
      description: '''Get a shallow index of all knowledge documents.

Returns a list of documents with just their metadata (path, title, type, tags).
Use this to quickly browse what knowledge is available without loading full content.

Example response:
```json
{
  "documents": [
    {"path": "global/decisions/jwt-auth.md", "title": "Use JWT Auth", "type": "decision", "tags": ["auth"]},
    {"path": "global/findings/api-structure.md", "title": "API Structure", "type": "finding"}
  ]
}
```''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'scope': {
            'type': 'string',
            'description':
                'Optional scope filter: "global", "team:{name}", or "agent:{name}". If omitted, returns all documents.',
          },
        },
      ),
      callback: ({args, extra}) async {
        try {
          final scope = args?['scope'] as String?;
          final documents = await _service.getIndex(scope: scope);
          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: jsonEncode({
                  'documents': documents.map((d) => d.toJson()).toList(),
                }),
              ),
            ],
          );
        } catch (e) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error getting knowledge index: $e')],
          );
        }
      },
    );
  }

  void _registerGetKnowledgeSummary(McpServer server) {
    server.tool(
      'getKnowledgeSummary',
      description: '''Get a knowledge document's metadata and summary.

Returns the document metadata plus its first paragraph as a summary.
Use this when you need more context than the index provides but don't need the full content.''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'path': {
            'type': 'string',
            'description':
                'Document path relative to knowledge root (e.g., "global/decisions/jwt-auth.md")',
          },
        },
        required: ['path'],
      ),
      callback: ({args, extra}) async {
        if (args == null || args['path'] == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: path is required')],
          );
        }

        try {
          final docPath = args['path'] as String;
          final document = await _service.getSummary(docPath);

          if (document == null) {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Document not found: $docPath')],
            );
          }

          return CallToolResult.fromContent(
            content: [TextContent(text: jsonEncode(document.toJson()))],
          );
        } catch (e) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error getting document summary: $e')],
          );
        }
      },
    );
  }

  void _registerReadKnowledge(McpServer server) {
    server.tool(
      'readKnowledge',
      description: '''Read the full content of a knowledge document.

Returns the complete document including all metadata and full markdown content.
Use this when you need to understand a document in detail.''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'path': {
            'type': 'string',
            'description':
                'Document path relative to knowledge root (e.g., "global/decisions/jwt-auth.md")',
          },
        },
        required: ['path'],
      ),
      callback: ({args, extra}) async {
        if (args == null || args['path'] == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: path is required')],
          );
        }

        try {
          final docPath = args['path'] as String;
          final document = await _service.readDocument(docPath);

          if (document == null) {
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Document not found: $docPath')],
            );
          }

          return CallToolResult.fromContent(
            content: [TextContent(text: jsonEncode(document.toJson()))],
          );
        } catch (e) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error reading document: $e')],
          );
        }
      },
    );
  }

  void _registerWriteKnowledge(McpServer server) {
    server.tool(
      'writeKnowledge',
      description: '''Write a knowledge document to the knowledge base.

Creates or updates a knowledge document with proper frontmatter.
The document will be saved to `.claude/knowledge/{path}`.

Document types:
- "decision" - Architectural decisions (ADRs)
- "finding" - Discovered facts about the codebase
- "pattern" - Recurring patterns or approaches
- "learning" - Lessons learned, what went wrong/right

Example:
```
writeKnowledge(
  path: "global/decisions/use-jwt.md",
  title: "Use JWT for Authentication",
  type: "decision",
  content: "## Context\\n\\nWe need stateless auth...\\n\\n## Decision\\n\\nWe chose JWT because...",
  tags: ["auth", "security"],
  references: ["lib/auth/jwt.dart:45"]
)
```''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'path': {
            'type': 'string',
            'description':
                'Document path (e.g., "global/decisions/use-jwt.md", "teams/auth/findings/token-format.md")',
          },
          'title': {
            'type': 'string',
            'description': 'Document title',
          },
          'type': {
            'type': 'string',
            'description':
                'Document type: "decision", "finding", "pattern", or "learning"',
          },
          'content': {
            'type': 'string',
            'description': 'Markdown content body (without frontmatter or title header)',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Optional tags for categorization',
          },
          'author': {
            'type': 'string',
            'description': 'Optional author name',
          },
          'references': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Optional code references (e.g., "lib/auth.dart:45")',
          },
        },
        required: ['path', 'title', 'type', 'content'],
      ),
      callback: ({args, extra}) async {
        if (args == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: No arguments provided')],
          );
        }

        final docPath = args['path'] as String?;
        final title = args['title'] as String?;
        final type = args['type'] as String?;
        final content = args['content'] as String?;

        if (docPath == null || title == null || type == null || content == null) {
          return CallToolResult.fromContent(
            content: [
              TextContent(text: 'Error: path, title, type, and content are required'),
            ],
          );
        }

        try {
          await _service.ensureDirectoryStructure();
          await _service.writeDocument(
            docPath: docPath,
            title: title,
            type: type,
            content: content,
            tags: (args['tags'] as List?)?.cast<String>(),
            author: args['author'] as String?,
            references: (args['references'] as List?)?.cast<String>(),
          );

          return CallToolResult.fromContent(
            content: [TextContent(text: 'Knowledge document written: $docPath')],
          );
        } catch (e) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error writing document: $e')],
          );
        }
      },
    );
  }

  void _registerSearchKnowledge(McpServer server) {
    server.tool(
      'searchKnowledge',
      description: '''Search knowledge documents by keyword.

Searches document titles, tags, and content for matching keywords.
Returns documents ranked by relevance with snippets showing where matches were found.''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'query': {
            'type': 'string',
            'description': 'Search query (keywords to search for)',
          },
          'scope': {
            'type': 'string',
            'description':
                'Optional scope: "global", "team:{name}", or "agent:{name}"',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum results to return (default: 10)',
          },
        },
        required: ['query'],
      ),
      callback: ({args, extra}) async {
        if (args == null || args['query'] == null) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: query is required')],
          );
        }

        try {
          final query = args['query'] as String;
          final scope = args['scope'] as String?;
          final limit = (args['limit'] as int?) ?? 10;

          final results = await _service.searchDocuments(
            query,
            scope: scope,
            limit: limit,
          );

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: jsonEncode({
                  'results': results.map((r) => r.toJson()).toList(),
                  'total': results.length,
                }),
              ),
            ],
          );
        } catch (e) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error searching knowledge: $e')],
          );
        }
      },
    );
  }

  void _registerListKnowledge(McpServer server) {
    server.tool(
      'listKnowledge',
      description: '''List knowledge documents filtered by type and/or tags.

Returns documents matching the specified filters.
More targeted than getKnowledgeIndex when you know what type of knowledge you need.''',
      toolInputSchema: ToolInputSchema(
        properties: {
          'scope': {
            'type': 'string',
            'description':
                'Optional scope: "global", "team:{name}", or "agent:{name}"',
          },
          'type': {
            'type': 'string',
            'description':
                'Filter by type: "decision", "finding", "pattern", "learning"',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Filter by tags (documents must have at least one matching tag)',
          },
        },
      ),
      callback: ({args, extra}) async {
        try {
          final scope = args?['scope'] as String?;
          final type = args?['type'] as String?;
          final tags = (args?['tags'] as List?)?.cast<String>();

          final documents = await _service.listDocuments(
            scope: scope,
            type: type,
            tags: tags,
          );

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: jsonEncode({
                  'documents': documents.map((d) => d.toJson()).toList(),
                  'total': documents.length,
                }),
              ),
            ],
          );
        } catch (e) {
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error listing knowledge: $e')],
          );
        }
      },
    );
  }
}
