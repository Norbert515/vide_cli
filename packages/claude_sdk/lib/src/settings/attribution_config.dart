import 'package:json_annotation/json_annotation.dart';

part 'attribution_config.g.dart';

/// Git attribution configuration for commits and PRs.
///
/// Customizes how Claude Code attributes its contributions
/// in git commits and pull request descriptions.
///
/// See: https://code.claude.com/docs/en/settings
@JsonSerializable(includeIfNull: false)
class AttributionConfig {
  /// Include "Generated with Claude Code" in commit messages.
  final bool? includeInCommitMessage;

  /// Include "Generated with Claude Code" in PR descriptions.
  final bool? includeInPrDescription;

  /// Include Co-Authored-By line in commits.
  final bool? includeCoAuthoredBy;

  const AttributionConfig({
    this.includeInCommitMessage,
    this.includeInPrDescription,
    this.includeCoAuthoredBy,
  });

  factory AttributionConfig.fromJson(Map<String, dynamic> json) =>
      _$AttributionConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AttributionConfigToJson(this);

  AttributionConfig copyWith({
    bool? includeInCommitMessage,
    bool? includeInPrDescription,
    bool? includeCoAuthoredBy,
  }) {
    return AttributionConfig(
      includeInCommitMessage:
          includeInCommitMessage ?? this.includeInCommitMessage,
      includeInPrDescription:
          includeInPrDescription ?? this.includeInPrDescription,
      includeCoAuthoredBy: includeCoAuthoredBy ?? this.includeCoAuthoredBy,
    );
  }
}
