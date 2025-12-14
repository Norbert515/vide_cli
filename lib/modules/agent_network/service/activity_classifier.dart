import 'dart:math';
import 'package:claude_api/claude_api.dart';

/// Classifies agent activity based on tool usage and generates
/// context-aware funny status messages.
class ActivityClassifier {
  static final _random = Random();

  /// Categories of activities with pools of funny messages
  static const _activityPools = {
    ActivityCategory.searching: [
      'Spelunking through the codebase',
      'Following the breadcrumbs',
      'Consulting the archives',
      'Hunting for clues',
      'Rummaging through files',
      'Excavating ancient code',
      'Tracking down the source',
      'Sifting through the haystack',
      'Scanning the horizon',
      'Peering into the abyss',
    ],
    ActivityCategory.reading: [
      'Speed-reading scrolls',
      'Absorbing knowledge',
      'Deciphering hieroglyphics',
      'Studying the sacred texts',
      'Parsing the manuscript',
      'Digesting documentation',
      'Consuming bytes',
      'Inhaling information',
    ],
    ActivityCategory.writing: [
      'Performing code surgery',
      'Wielding the keyboard sword',
      'Crafting artisanal code',
      'Channeling the coding spirits',
      'Sculpting bytes',
      'Weaving digital tapestry',
      'Inscribing incantations',
      'Forging new pathways',
    ],
    ActivityCategory.running: [
      'Whispering to the terminal',
      'Spinning up hamster wheels',
      'Feeding the build monster',
      'Summoning the shell spirits',
      'Executing ancient rituals',
      'Poking the system',
      'Rattling the cages',
      'Cranking the machinery',
    ],
    ActivityCategory.testing: [
      'Interrogating the test suite',
      'Cross-examining assertions',
      'Stress-testing sanity',
      'Probing for weaknesses',
      'Running the gauntlet',
      'Challenging the validators',
    ],
    ActivityCategory.networking: [
      'Consulting the oracle',
      'Reaching across the void',
      'Fetching wisdom from afar',
      'Pinging the cosmos',
      'Downloading enlightenment',
      'Surfing the waves',
    ],
    ActivityCategory.spawning: [
      'Cloning myself',
      'Summoning minions',
      'Dispatching helpers',
      'Multiplying efforts',
      'Delegating to the troops',
      'Spawning reinforcements',
    ],
    ActivityCategory.planning: [
      'Plotting the course',
      'Scheming strategically',
      'Mapping the journey',
      'Charting the path forward',
      'Orchestrating the plan',
    ],
    ActivityCategory.thinking: [
      'Pondering the universe',
      'Consulting neural networks',
      'Brewing thoughts',
      'Contemplating existence',
      'Processing possibilities',
      'Calculating outcomes',
      'Meditating on the problem',
      'Letting ideas simmer',
      'Connecting the dots',
      'Ruminating deeply',
    ],
    ActivityCategory.idle: [
      'Warming up the hamster wheel',
      'Calibrating quantum flux capacitors',
      'Reticulating splines',
      'Aligning chakras with CPU cores',
      'Polishing the bits',
      'Defragmenting consciousness',
      'Shaking the magic 8-ball',
      'Petting the server hamsters',
      'Adjusting reality parameters',
      'Synchronizing with the cosmos',
    ],
  };

  /// Maps tool names to activity categories
  static ActivityCategory categorizeToolName(String toolName) {
    final name = toolName.toLowerCase();

    // Searching/Finding
    if (name == 'grep' || name == 'glob' || name == 'websearch') {
      return ActivityCategory.searching;
    }

    // Reading
    if (name == 'read') {
      return ActivityCategory.reading;
    }

    // Writing/Editing
    if (name == 'write' || name == 'edit' || name == 'multiedit' || name == 'notebookedit') {
      return ActivityCategory.writing;
    }

    // Running commands
    if (name == 'bash' || name == 'killshell') {
      return ActivityCategory.running;
    }

    // Testing (often done via bash, but can detect from context)
    // We'll handle this specially based on bash command content

    // Networking
    if (name == 'webfetch') {
      return ActivityCategory.networking;
    }

    // Spawning agents
    if (name == 'task' || name == 'spawnagent' || name.startsWith('mcp__vide-agent__spawn')) {
      return ActivityCategory.spawning;
    }

    // Planning/Organizing
    if (name == 'todowrite' || name == 'enterplanmode' || name == 'exitplanmode') {
      return ActivityCategory.planning;
    }

    // Agent communication
    if (name.contains('sendmessage') || name.contains('setagentstatus')) {
      return ActivityCategory.spawning;
    }

    // Git operations (treat as running)
    if (name.startsWith('mcp__vide-git__')) {
      return ActivityCategory.running;
    }

    // Memory operations
    if (name.startsWith('mcp__vide-memory__')) {
      return ActivityCategory.reading;
    }

    // Default to thinking
    return ActivityCategory.thinking;
  }

  /// Gets a random message for the given category
  static String getRandomMessageForCategory(ActivityCategory category) {
    final pool = _activityPools[category] ?? _activityPools[ActivityCategory.idle]!;
    return pool[_random.nextInt(pool.length)];
  }

  /// Generates a context-aware activity message based on tool usage
  static ActivityMessage classifyToolUse(ToolUseResponse tool) {
    final category = categorizeToolName(tool.toolName);
    final baseMessage = getRandomMessageForCategory(category);

    // Extract context from parameters for more specific messages
    final context = _extractContext(tool.toolName, tool.parameters);

    return ActivityMessage(
      category: category,
      message: baseMessage,
      context: context,
      toolName: tool.toolName,
    );
  }

  /// Extracts relevant context from tool parameters
  static String? _extractContext(String toolName, Map<String, dynamic> params) {
    final name = toolName.toLowerCase();

    // File operations - extract filename
    if (name == 'read' || name == 'write' || name == 'edit') {
      final path = params['file_path'] as String?;
      if (path != null) {
        return _extractFilename(path);
      }
    }

    // Grep - extract pattern
    if (name == 'grep') {
      return params['pattern'] as String?;
    }

    // Glob - extract pattern
    if (name == 'glob') {
      return params['pattern'] as String?;
    }

    // Bash - extract description or command preview
    if (name == 'bash') {
      final desc = params['description'] as String?;
      if (desc != null) return desc;

      final command = params['command'] as String?;
      if (command != null) {
        // Truncate long commands
        return command.length > 30 ? '${command.substring(0, 27)}...' : command;
      }
    }

    // WebSearch - extract query
    if (name == 'websearch') {
      return params['query'] as String?;
    }

    // WebFetch - extract domain
    if (name == 'webfetch') {
      final url = params['url'] as String?;
      if (url != null) {
        return _extractDomain(url);
      }
    }

    // Task/SpawnAgent - extract agent name or type
    if (name == 'task' || name == 'spawnagent' || name.contains('spawn')) {
      return params['name'] as String? ?? params['subagent_type'] as String? ?? params['agentType'] as String?;
    }

    return null;
  }

  static String _extractFilename(String path) {
    final parts = path.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }

  static String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return url;
    }
  }
}

/// Categories of agent activity
enum ActivityCategory {
  searching,
  reading,
  writing,
  running,
  testing,
  networking,
  spawning,
  planning,
  thinking,
  idle,
}

/// Represents a classified activity with context
class ActivityMessage {
  final ActivityCategory category;
  final String message;
  final String? context;
  final String? toolName;

  const ActivityMessage({
    required this.category,
    required this.message,
    this.context,
    this.toolName,
  });

  /// Formats the activity message for display
  /// If context is available, shows "Message `context`..."
  /// Otherwise just shows "Message..."
  String format() {
    if (context != null && context!.isNotEmpty) {
      return '$message `$context`';
    }
    return message;
  }
}
