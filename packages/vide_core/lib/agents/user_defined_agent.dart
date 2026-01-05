import 'package:yaml/yaml.dart';
import 'agent_configuration.dart';
import '../mcp/mcp_server_type.dart';

/// Represents a user-defined agent loaded from a markdown file.
///
/// User-defined agents are defined in `.claude/agents/*.md` files using YAML frontmatter
/// and a markdown body containing the system prompt.
class UserDefinedAgent {
  /// Unique identifier for the agent (e.g., "code-reviewer")
  final String name;

  /// Description of when this agent should be invoked
  final String description;

  /// The system prompt from the markdown body
  final String systemPrompt;

  /// Optional list of MCP server names this agent can access
  /// If null, inherits all MCP servers from main agent
  /// If empty list, has no MCP servers
  /// Otherwise, only the specified servers are available
  ///
  /// Examples: ["vide-git", "vide-memory", "dart"]
  final List<String>? mcpServers;

  /// Optional list of tool names this agent can access
  /// If null, inherits all tools from main agent (Claude Code default behavior)
  final List<String>? tools;

  /// Optional model selection: 'sonnet', 'opus', 'haiku', or 'inherit'
  /// Defaults to 'sonnet' if not specified
  final String? model;

  /// Path to the source markdown file
  final String filePath;

  const UserDefinedAgent({
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.filePath,
    this.mcpServers,
    this.tools,
    this.model,
  });

  /// Parses an agent definition from markdown content.
  ///
  /// Expected format:
  /// ```markdown
  /// ---
  /// name: agent-name
  /// description: When to use this agent
  /// mcpServers: vide-git, vide-memory  # Optional
  /// tools: Read, Grep, Glob, Bash          # Optional
  /// model: sonnet                           # Optional
  /// ---
  ///
  /// System prompt content here...
  /// ```
  ///
  /// Throws [FormatException] if the markdown is malformed.
  static UserDefinedAgent fromMarkdown(String content, String filePath) {
    // Extract frontmatter and body
    final parts = _extractFrontmatter(content);
    if (parts == null) {
      throw FormatException(
        'Invalid agent definition: missing YAML frontmatter in $filePath',
      );
    }

    final (frontmatterText, body) = parts;

    // Parse YAML frontmatter
    final YamlMap yaml;
    try {
      yaml = loadYaml(frontmatterText) as YamlMap;
    } catch (e) {
      throw FormatException('Invalid YAML frontmatter in $filePath: $e');
    }

    // Extract required fields
    final name = yaml['name'] as String?;
    final description = yaml['description'] as String?;

    if (name == null || name.isEmpty) {
      throw FormatException('Missing required field "name" in $filePath');
    }
    if (description == null || description.isEmpty) {
      throw FormatException(
        'Missing required field "description" in $filePath',
      );
    }

    // Extract optional MCP servers field
    final mcpServersField = yaml['mcpServers'];
    List<String>? mcpServers;
    if (mcpServersField != null) {
      if (mcpServersField is String) {
        // Parse comma-separated list: "vide-git, vide-memory"
        mcpServers = mcpServersField
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (mcpServersField is YamlList) {
        // Parse YAML list: [vide-git, vide-memory]
        mcpServers = mcpServersField.cast<String>().toList();
      }
    }

    // Extract optional tools field
    final toolsField = yaml['tools'];
    List<String>? tools;
    if (toolsField != null) {
      if (toolsField is String) {
        // Parse comma-separated list: "Read, Grep, Glob"
        tools = toolsField
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      } else if (toolsField is YamlList) {
        // Parse YAML list: [Read, Grep, Glob]
        tools = toolsField.cast<String>().toList();
      }
    }

    final model = yaml['model'] as String?;

    // Trim system prompt
    final systemPrompt = body.trim();
    if (systemPrompt.isEmpty) {
      throw FormatException(
        'Missing system prompt (markdown body) in $filePath',
      );
    }

    return UserDefinedAgent(
      name: name,
      description: description,
      systemPrompt: systemPrompt,
      filePath: filePath,
      mcpServers: mcpServers,
      tools: tools,
      model: model,
    );
  }

  /// Extracts YAML frontmatter and markdown body from content.
  ///
  /// Returns (frontmatter, body) or null if no frontmatter found.
  static (String, String)? _extractFrontmatter(String content) {
    // Match YAML frontmatter: ---\n...\n---\n
    final pattern = RegExp(
      r'^---\s*\n(.*?)\n---\s*\n(.*)$',
      dotAll: true,
      multiLine: true,
    );

    final match = pattern.firstMatch(content);
    if (match == null) {
      return null;
    }

    final frontmatter = match.group(1) ?? '';
    final body = match.group(2) ?? '';

    return (frontmatter, body);
  }

  /// Convert to AgentConfiguration
  AgentConfiguration toAgentConfiguration() {
    // Parse MCP server names into McpServerType instances
    List<McpServerType>? parsedMcpServers;
    if (mcpServers != null) {
      parsedMcpServers = mcpServers!.map((serverName) {
        // Check if it's a built-in server
        switch (serverName) {
          case 'vide-git':
            return McpServerType.git;
          case 'vide-memory':
            return McpServerType.memory;
          case 'vide-task-management':
            return McpServerType.taskManagement;
          case 'flutter-runtime':
            return McpServerType.flutterRuntime;
          case 'figma-remote-mcp':
            return McpServerType.figma;
          default:
            // Assume it's a custom server
            return McpServerType.custom(serverName);
        }
      }).toList();
    }

    return AgentConfiguration(
      name: name,
      description: description,
      systemPrompt: systemPrompt,
      mcpServers: parsedMcpServers,
      allowedTools: tools,
      model: model,
    );
  }

  @override
  String toString() {
    return 'UserDefinedAgent(name: $name, description: $description, '
        'mcpServers: ${mcpServers ?? "inherited"}, '
        'tools: ${tools ?? "inherited"}, '
        'model: ${model ?? "sonnet"})';
  }
}
