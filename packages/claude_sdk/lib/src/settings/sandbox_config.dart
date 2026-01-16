import 'package:json_annotation/json_annotation.dart';

part 'sandbox_config.g.dart';

/// Sandbox configuration for command execution.
///
/// The sandbox isolates command execution to prevent unintended
/// system modifications. Network access can be controlled through
/// proxy settings.
///
/// See: https://code.claude.com/docs/en/settings#sandbox
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class SandboxConfig {
  /// Enable sandbox mode for command execution.
  final bool? enabled;

  /// Auto-allow bash commands when running in sandboxed mode.
  final bool? autoAllowBashIfSandboxed;

  /// Commands excluded from sandboxing.
  /// Example: ["git", "docker"]
  final List<String>? excludedCommands;

  /// Allow commands that cannot be sandboxed to run unsandboxed.
  final bool? allowUnsandboxedCommands;

  /// Network configuration for sandboxed processes.
  final SandboxNetworkConfig? network;

  const SandboxConfig({
    this.enabled,
    this.autoAllowBashIfSandboxed,
    this.excludedCommands,
    this.allowUnsandboxedCommands,
    this.network,
  });

  factory SandboxConfig.fromJson(Map<String, dynamic> json) =>
      _$SandboxConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SandboxConfigToJson(this);

  SandboxConfig copyWith({
    bool? enabled,
    bool? autoAllowBashIfSandboxed,
    List<String>? excludedCommands,
    bool? allowUnsandboxedCommands,
    SandboxNetworkConfig? network,
  }) {
    return SandboxConfig(
      enabled: enabled ?? this.enabled,
      autoAllowBashIfSandboxed:
          autoAllowBashIfSandboxed ?? this.autoAllowBashIfSandboxed,
      excludedCommands: excludedCommands ?? this.excludedCommands,
      allowUnsandboxedCommands:
          allowUnsandboxedCommands ?? this.allowUnsandboxedCommands,
      network: network ?? this.network,
    );
  }
}

/// Network configuration for sandboxed processes.
@JsonSerializable(includeIfNull: false)
class SandboxNetworkConfig {
  /// Unix sockets to allow access to.
  /// Example: ["~/.ssh/agent-socket"]
  final List<String>? allowUnixSockets;

  /// Allow processes to bind to local ports.
  final bool? allowLocalBinding;

  /// HTTP proxy port for sandboxed network access.
  final int? httpProxyPort;

  /// SOCKS proxy port for sandboxed network access.
  final int? socksProxyPort;

  const SandboxNetworkConfig({
    this.allowUnixSockets,
    this.allowLocalBinding,
    this.httpProxyPort,
    this.socksProxyPort,
  });

  factory SandboxNetworkConfig.fromJson(Map<String, dynamic> json) =>
      _$SandboxNetworkConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SandboxNetworkConfigToJson(this);

  SandboxNetworkConfig copyWith({
    List<String>? allowUnixSockets,
    bool? allowLocalBinding,
    int? httpProxyPort,
    int? socksProxyPort,
  }) {
    return SandboxNetworkConfig(
      allowUnixSockets: allowUnixSockets ?? this.allowUnixSockets,
      allowLocalBinding: allowLocalBinding ?? this.allowLocalBinding,
      httpProxyPort: httpProxyPort ?? this.httpProxyPort,
      socksProxyPort: socksProxyPort ?? this.socksProxyPort,
    );
  }
}
