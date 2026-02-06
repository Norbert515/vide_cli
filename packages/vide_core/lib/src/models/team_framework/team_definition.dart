import 'package:yaml/yaml.dart';

/// Configuration for a lifecycle trigger that spawns an agent.
class LifecycleTriggerConfig {
  const LifecycleTriggerConfig({required this.enabled, required this.spawn});

  /// Whether this trigger is enabled
  final bool enabled;

  /// Agent type to spawn when trigger fires
  final String spawn;

  factory LifecycleTriggerConfig.fromYaml(Map<String, dynamic> yaml) {
    return LifecycleTriggerConfig(
      enabled: yaml['enabled'] as bool? ?? true,
      spawn: yaml['spawn'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'LifecycleTriggerConfig(enabled: $enabled, spawn: $spawn)';
}

/// Represents a team composition loaded from a .md file.
///
/// Teams define how agents work together, including:
/// - The main agent personality for orchestration
/// - Available agent personalities for spawning
/// - Process configuration (planning, review, testing levels)
/// - Communication style settings
/// - Trigger patterns for team selection
/// - Lifecycle triggers that spawn agents at specific points
class TeamDefinition {
  const TeamDefinition({
    required this.name,
    required this.description,
    required this.filePath,
    required this.mainAgent,
    this.icon,
    this.agents = const [],
    this.include = const [],
    this.process = const ProcessConfig(),
    this.communication = const CommunicationConfig(),
    this.triggers = const [],
    this.antiTriggers = const [],
    this.lifecycleTriggers = const {},
    this.content = '',
  });

  /// Unique identifier for the team (e.g., "startup", "enterprise")
  final String name;

  /// Human-readable description of when to use this team
  final String description;

  /// Path to the source markdown file
  final String filePath;

  /// Optional icon for display (e.g., "🚀")
  final String? icon;

  /// The agent personality name for the main agent (e.g., "vide-main-orchestrator")
  final String mainAgent;

  /// List of agent personality names available to spawn
  final List<String> agents;

  /// Include paths resolved for all agents in this team (e.g., "etiquette/messaging")
  final List<String> include;

  /// Process configuration for this team
  final ProcessConfig process;

  /// Communication style for this team
  final CommunicationConfig communication;

  /// Keywords that suggest this team should be used
  final List<String> triggers;

  /// Keywords that suggest this team should NOT be used
  final List<String> antiTriggers;

  /// Lifecycle triggers that spawn agents at specific points.
  /// Keys are trigger point names (e.g., "onSessionEnd", "onTaskComplete").
  final Map<String, LifecycleTriggerConfig> lifecycleTriggers;

  /// The markdown body content (team description/philosophy)
  final String content;

  /// Parse a team definition from markdown content with YAML frontmatter.
  factory TeamDefinition.fromMarkdown(String content, String filePath) {
    final parts = _extractFrontmatter(content);
    if (parts == null) {
      throw FormatException(
        'Invalid team definition: missing YAML frontmatter in $filePath',
      );
    }

    final (frontmatterText, body) = parts;

    final YamlMap yaml;
    try {
      yaml = loadYaml(frontmatterText) as YamlMap;
    } catch (e) {
      throw FormatException('Invalid YAML frontmatter in $filePath: $e');
    }

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

    // Parse main-agent (required)
    final mainAgent = yaml['main-agent'] as String?;
    if (mainAgent == null || mainAgent.isEmpty) {
      throw FormatException('Missing required field "main-agent" in $filePath');
    }

    // Parse agents list
    final agentsYaml = yaml['agents'] as YamlList?;
    final agents = agentsYaml?.cast<String>().toList() ?? [];

    // Parse include list
    final includeYaml = yaml['include'] as YamlList?;
    final include = includeYaml?.cast<String>().toList() ?? [];

    // Parse process config
    final processYaml = yaml['process'] as YamlMap?;
    final process = processYaml != null
        ? ProcessConfig.fromYaml(processYaml)
        : const ProcessConfig();

    // Parse communication config
    final commYaml = yaml['communication'] as YamlMap?;
    final communication = commYaml != null
        ? CommunicationConfig.fromYaml(commYaml)
        : const CommunicationConfig();

    // Parse triggers
    final triggersYaml = yaml['triggers'] as YamlList?;
    final triggers = triggersYaml?.cast<String>().toList() ?? [];

    // Parse anti-triggers
    final antiTriggersYaml = yaml['anti-triggers'] as YamlList?;
    final antiTriggers = antiTriggersYaml?.cast<String>().toList() ?? [];

    // Parse lifecycle triggers
    final lifecycleTriggersYaml = yaml['lifecycle-triggers'] as YamlMap?;
    final lifecycleTriggers = <String, LifecycleTriggerConfig>{};
    if (lifecycleTriggersYaml != null) {
      for (final entry in lifecycleTriggersYaml.entries) {
        final triggerName = entry.key as String;
        final triggerYaml = entry.value;
        if (triggerYaml is YamlMap) {
          lifecycleTriggers[triggerName] = LifecycleTriggerConfig.fromYaml(
            Map<String, dynamic>.from(triggerYaml),
          );
        }
      }
    }

    return TeamDefinition(
      name: name,
      description: description,
      filePath: filePath,
      mainAgent: mainAgent,
      icon: yaml['icon'] as String?,
      agents: agents,
      include: include,
      process: process,
      communication: communication,
      triggers: triggers,
      antiTriggers: antiTriggers,
      lifecycleTriggers: lifecycleTriggers,
      content: body.trim(),
    );
  }

  /// Check if this team matches the given task description.
  /// Returns a score (higher = better match, 0 = no match, negative = anti-match)
  int matchScore(String taskDescription) {
    final lowerTask = taskDescription.toLowerCase();
    var score = 0;

    // Check anti-triggers first (disqualifying)
    for (final anti in antiTriggers) {
      if (lowerTask.contains(anti.toLowerCase())) {
        return -100; // Strong negative signal
      }
    }

    // Check triggers
    for (final trigger in triggers) {
      if (lowerTask.contains(trigger.toLowerCase())) {
        score += 10;
      }
    }

    return score;
  }

  @override
  String toString() {
    return 'TeamDefinition(name: $name, mainAgent: $mainAgent, agents: $agents)';
  }
}

/// Process configuration for a team
class ProcessConfig {
  const ProcessConfig({
    this.planning = ProcessLevel.standard,
    this.review = ReviewLevel.optional,
    this.testing = TestingLevel.recommended,
    this.documentation = DocumentationLevel.inlineOnly,
  });

  final ProcessLevel planning;
  final ReviewLevel review;
  final TestingLevel testing;
  final DocumentationLevel documentation;

  factory ProcessConfig.fromYaml(YamlMap yaml) {
    return ProcessConfig(
      planning: ProcessLevel.fromString(yaml['planning'] as String?),
      review: ReviewLevel.fromString(yaml['review'] as String?),
      testing: TestingLevel.fromString(yaml['testing'] as String?),
      documentation: DocumentationLevel.fromString(
        yaml['documentation'] as String?,
      ),
    );
  }
}

/// Communication style configuration
class CommunicationConfig {
  const CommunicationConfig({
    this.verbosity = Verbosity.medium,
    this.handoffDetail = DetailLevel.standard,
    this.statusUpdates = UpdateFrequency.onMilestones,
  });

  final Verbosity verbosity;
  final DetailLevel handoffDetail;
  final UpdateFrequency statusUpdates;

  factory CommunicationConfig.fromYaml(YamlMap yaml) {
    return CommunicationConfig(
      verbosity: Verbosity.fromString(yaml['verbosity'] as String?),
      handoffDetail: DetailLevel.fromString(yaml['handoff-detail'] as String?),
      statusUpdates: UpdateFrequency.fromString(
        yaml['status-updates'] as String?,
      ),
    );
  }
}

// Enums for configuration options

enum ProcessLevel {
  minimal,
  standard,
  thorough,
  adaptive;

  static ProcessLevel fromString(String? value) {
    return ProcessLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ProcessLevel.standard,
    );
  }
}

enum ReviewLevel {
  skip,
  optional,
  required;

  static ReviewLevel fromString(String? value) {
    return ReviewLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReviewLevel.optional,
    );
  }
}

enum TestingLevel {
  skip,
  smokeOnly,
  recommended,
  comprehensive;

  static TestingLevel fromString(String? value) {
    final normalized = value?.replaceAll('-', '').toLowerCase();
    return TestingLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => TestingLevel.recommended,
    );
  }
}

enum DocumentationLevel {
  skip,
  inlineOnly,
  full,
  findingsOnly;

  static DocumentationLevel fromString(String? value) {
    final normalized = value?.replaceAll('-', '').toLowerCase();
    return DocumentationLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => DocumentationLevel.inlineOnly,
    );
  }
}

enum Verbosity {
  low,
  medium,
  high;

  static Verbosity fromString(String? value) {
    return Verbosity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Verbosity.medium,
    );
  }
}

enum DetailLevel {
  minimal,
  standard,
  comprehensive;

  static DetailLevel fromString(String? value) {
    return DetailLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DetailLevel.standard,
    );
  }
}

enum UpdateFrequency {
  continuous,
  onMilestones,
  onCompletion;

  static UpdateFrequency fromString(String? value) {
    final normalized = value?.replaceAll('-', '').toLowerCase();
    return UpdateFrequency.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => UpdateFrequency.onMilestones,
    );
  }
}

/// Extract YAML frontmatter and markdown body from content.
(String, String)? _extractFrontmatter(String content) {
  final pattern = RegExp(
    r'^---\s*\n(.*?)\n---\s*\n(.*)$',
    dotAll: true,
    multiLine: true,
  );

  final match = pattern.firstMatch(content);
  if (match == null) return null;

  return (match.group(1) ?? '', match.group(2) ?? '');
}
