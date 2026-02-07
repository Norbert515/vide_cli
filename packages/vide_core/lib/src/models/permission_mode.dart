/// Permission modes for agent tool usage.
///
/// These control how tool invocations are approved:
/// - CLI modes map directly to Claude CLI `--permission-mode` values
/// - [ask] is a vide-specific mode for interactive approval via UI
enum PermissionMode {
  /// Vide-specific: prompt the user via UI (WebSocket/TUI dialog).
  /// Translated to [defaultMode] for the Claude CLI, with the SDK callback
  /// handling actual permission decisions.
  ask('ask'),

  /// Auto-approve file write operations (Edit, Write, MultiEdit).
  acceptEdits('acceptEdits'),

  /// Skip all permission checks. DANGEROUS — only for sandboxed environments.
  bypassPermissions('bypassPermissions'),

  /// Default Claude CLI behavior — prompt for dangerous operations.
  defaultMode('default'),

  /// Delegate permission decisions to the SDK callback.
  delegate('delegate'),

  /// Auto-approve everything without asking.
  dontAsk('dontAsk'),

  /// Planning mode — read-only, no writes.
  plan('plan');

  /// The wire-format string used in CLI args, configs, and YAML.
  final String value;

  const PermissionMode(this.value);

  /// Parse a string into a [PermissionMode].
  ///
  /// Throws [ArgumentError] if the string is not a valid mode.
  static PermissionMode parse(String mode) {
    for (final m in values) {
      if (m.value == mode) return m;
    }
    throw ArgumentError(
      'Invalid permission mode: $mode. '
      'Valid modes are: ${values.map((m) => m.value).join(", ")}',
    );
  }

  /// Try to parse a string into a [PermissionMode], returning null on failure.
  static PermissionMode? tryParse(String mode) {
    for (final m in values) {
      if (m.value == mode) return m;
    }
    return null;
  }

  /// The CLI-compatible mode string.
  ///
  /// Translates vide-specific modes to their CLI equivalents.
  String get cliValue => switch (this) {
    ask => defaultMode.value,
    _ => value,
  };
}
