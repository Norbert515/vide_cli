import 'package:json_annotation/json_annotation.dart';

part 'permissions_config.g.dart';

/// Permission rules for tool access in Claude Code.
///
/// Permissions follow a priority order: deny > ask > allow.
/// Tools not matching any rule follow the defaultMode.
///
/// Pattern syntax:
/// - `Bash(npm run:*)` - Match bash commands starting with "npm run"
/// - `Read(~/.zshrc)` - Match specific file paths
/// - `WebFetch` - Match entire tool category
/// - `Read(./.env)` - Match relative paths
///
/// See: https://code.claude.com/docs/en/settings#permissions
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class PermissionsConfig {
  /// Tools/patterns to allow without confirmation.
  /// Example: ["Bash(npm run:*)", "Read(~/.zshrc)"]
  final List<String>? allow;

  /// Tools/patterns to deny completely.
  /// Example: ["WebFetch", "Read(./.env)"]
  final List<String>? deny;

  /// Tools/patterns that require user confirmation.
  /// Example: ["Bash(git push:*)"]
  final List<String>? ask;

  /// Additional directories to grant access to.
  /// Example: ["../docs/", "/shared/resources/"]
  final List<String>? additionalDirectories;

  /// Default permission behavior for unmatched tools.
  /// Values: "acceptEdits", "allowAll", "denyAll", "askAll"
  final String? defaultMode;

  /// Prevent bypass of permission restrictions.
  final bool? disableBypassPermissionsMode;

  const PermissionsConfig({
    this.allow,
    this.deny,
    this.ask,
    this.additionalDirectories,
    this.defaultMode,
    this.disableBypassPermissionsMode,
  });

  /// Creates an empty permissions config.
  factory PermissionsConfig.empty() => const PermissionsConfig(
        allow: [],
        deny: [],
        ask: [],
      );

  factory PermissionsConfig.fromJson(Map<String, dynamic> json) =>
      _$PermissionsConfigFromJson(json);

  Map<String, dynamic> toJson() => _$PermissionsConfigToJson(this);

  PermissionsConfig copyWith({
    List<String>? allow,
    List<String>? deny,
    List<String>? ask,
    List<String>? additionalDirectories,
    String? defaultMode,
    bool? disableBypassPermissionsMode,
  }) {
    return PermissionsConfig(
      allow: allow ?? this.allow,
      deny: deny ?? this.deny,
      ask: ask ?? this.ask,
      additionalDirectories: additionalDirectories ?? this.additionalDirectories,
      defaultMode: defaultMode ?? this.defaultMode,
      disableBypassPermissionsMode:
          disableBypassPermissionsMode ?? this.disableBypassPermissionsMode,
    );
  }

  /// Check if a pattern is in the allow list.
  bool isAllowed(String pattern) => allow?.contains(pattern) ?? false;

  /// Check if a pattern is in the deny list.
  bool isDenied(String pattern) => deny?.contains(pattern) ?? false;

  /// Check if a pattern requires asking.
  bool requiresAsk(String pattern) => ask?.contains(pattern) ?? false;
}
