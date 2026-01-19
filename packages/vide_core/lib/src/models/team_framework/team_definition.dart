import 'package:yaml/yaml.dart';

/// Represents a team composition loaded from a .md file.
///
/// Teams define how agents work together, including:
/// - Which agent personalities fill which roles
/// - Process configuration (planning, review, testing levels)
/// - Communication style settings
/// - Trigger patterns for team selection
class TeamDefinition {
  const TeamDefinition({
    required this.name,
    required this.description,
    required this.filePath,
    this.icon,
    this.composition = const {},
    this.process = const ProcessConfig(),
    this.communication = const CommunicationConfig(),
    this.triggers = const [],
    this.antiTriggers = const [],
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

  /// Maps role names to agent personality names
  /// e.g., {"lead": "pragmatic-lead", "implementer": "speed-demon"}
  final Map<String, String?> composition;

  /// Process configuration for this team
  final ProcessConfig process;

  /// Communication style for this team
  final CommunicationConfig communication;

  /// Keywords that suggest this team should be used
  final List<String> triggers;

  /// Keywords that suggest this team should NOT be used
  final List<String> antiTriggers;

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
      throw FormatException('Missing required field "description" in $filePath');
    }

    // Parse composition
    final compositionYaml = yaml['composition'] as YamlMap?;
    final composition = <String, String?>{};
    if (compositionYaml != null) {
      for (final entry in compositionYaml.entries) {
        final value = entry.value;
        composition[entry.key as String] = value == null ? null : value as String;
      }
    }

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

    return TeamDefinition(
      name: name,
      description: description,
      filePath: filePath,
      icon: yaml['icon'] as String?,
      composition: composition,
      process: process,
      communication: communication,
      triggers: triggers,
      antiTriggers: antiTriggers,
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
    return 'TeamDefinition(name: $name, composition: $composition)';
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
      documentation: DocumentationLevel.fromString(yaml['documentation'] as String?),
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
      statusUpdates: UpdateFrequency.fromString(yaml['status-updates'] as String?),
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
