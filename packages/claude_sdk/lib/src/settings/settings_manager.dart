import 'dart:convert';
import 'dart:io';

import 'claude_settings.dart';
import 'mcp_config.dart';
import 'permissions_config.dart';

/// Scope for settings operations.
enum SettingsScope {
  /// User-level settings: ~/.claude/settings.json
  user,

  /// Project-level shared settings: .claude/settings.json
  project,

  /// Project-level local settings: .claude/settings.local.json
  local,
}

/// Service for reading and writing Claude Code settings files.
///
/// Handles the hierarchy of settings files:
/// - User settings: ~/.claude/settings.json
/// - Project settings: .claude/settings.json
/// - Local settings: .claude/settings.local.json
///
/// Also handles .mcp.json for MCP server definitions.
class ClaudeSettingsManager {
  final String? _projectRoot;
  final String? _userHome;

  /// Creates a settings manager.
  ///
  /// [projectRoot] is the project directory containing .claude/ folder.
  /// [userHome] is the user's home directory (defaults to Platform.environment['HOME']).
  ClaudeSettingsManager({String? projectRoot, String? userHome})
    : _projectRoot = projectRoot,
      _userHome = userHome ?? Platform.environment['HOME'];

  // ============================================
  // Path Helpers
  // ============================================

  String? get _userSettingsPath =>
      _userHome != null ? '$_userHome/.claude/settings.json' : null;

  String? get _projectSettingsPath =>
      _projectRoot != null ? '$_projectRoot/.claude/settings.json' : null;

  String? get _localSettingsPath =>
      _projectRoot != null ? '$_projectRoot/.claude/settings.local.json' : null;

  String? get _mcpJsonPath =>
      _projectRoot != null ? '$_projectRoot/.mcp.json' : null;

  // Note: User-level .mcp.json support can be added when needed
  // String? get _userMcpJsonPath =>
  //     _userHome != null ? '$_userHome/.mcp.json' : null;

  String? _getPathForScope(SettingsScope scope) {
    switch (scope) {
      case SettingsScope.user:
        return _userSettingsPath;
      case SettingsScope.project:
        return _projectSettingsPath;
      case SettingsScope.local:
        return _localSettingsPath;
    }
  }

  // ============================================
  // Read Operations
  // ============================================

  /// Read settings from a specific scope.
  ///
  /// Returns empty settings if file doesn't exist.
  Future<ClaudeSettings> readSettings(SettingsScope scope) async {
    final path = _getPathForScope(scope);
    if (path == null) return ClaudeSettings.empty();

    return _readSettingsFile(path);
  }

  /// Read settings synchronously from a specific scope.
  ///
  /// Returns empty settings if file doesn't exist.
  ClaudeSettings readSettingsSync(SettingsScope scope) {
    final path = _getPathForScope(scope);
    if (path == null) return ClaudeSettings.empty();

    return _readSettingsFileSync(path);
  }

  /// Read and merge settings from all scopes.
  ///
  /// Settings are merged in order: user -> project -> local,
  /// where more specific settings override general ones.
  Future<ClaudeSettings> readMergedSettings() async {
    var settings = ClaudeSettings.empty();

    // User settings (lowest priority)
    settings = settings.merge(await readSettings(SettingsScope.user));

    // Project settings
    settings = settings.merge(await readSettings(SettingsScope.project));

    // Local settings (highest priority)
    settings = settings.merge(await readSettings(SettingsScope.local));

    return settings;
  }

  /// Read and merge settings synchronously from all scopes.
  ClaudeSettings readMergedSettingsSync() {
    var settings = ClaudeSettings.empty();

    settings = settings.merge(readSettingsSync(SettingsScope.user));
    settings = settings.merge(readSettingsSync(SettingsScope.project));
    settings = settings.merge(readSettingsSync(SettingsScope.local));

    return settings;
  }

  /// Read MCP server definitions from .mcp.json.
  Future<McpJsonConfig> readMcpJson() async {
    if (_mcpJsonPath == null) return const McpJsonConfig();
    return _readMcpJsonFile(_mcpJsonPath!);
  }

  /// Read MCP server definitions synchronously.
  McpJsonConfig readMcpJsonSync() {
    if (_mcpJsonPath == null) return const McpJsonConfig();
    return _readMcpJsonFileSync(_mcpJsonPath!);
  }

  // ============================================
  // Write Operations
  // ============================================

  /// Write settings to a specific scope.
  ///
  /// Creates the .claude directory if it doesn't exist.
  Future<void> writeSettings(
    ClaudeSettings settings,
    SettingsScope scope,
  ) async {
    final path = _getPathForScope(scope);
    if (path == null) {
      throw StateError('Cannot write to $scope scope: path not configured');
    }

    await _writeSettingsFile(path, settings);
  }

  /// Write settings synchronously.
  void writeSettingsSync(ClaudeSettings settings, SettingsScope scope) {
    final path = _getPathForScope(scope);
    if (path == null) {
      throw StateError('Cannot write to $scope scope: path not configured');
    }

    _writeSettingsFileSync(path, settings);
  }

  /// Update settings in a specific scope using a callback.
  ///
  /// Reads current settings, applies the update, and writes back.
  Future<void> updateSettings(
    SettingsScope scope,
    ClaudeSettings Function(ClaudeSettings current) update,
  ) async {
    final current = await readSettings(scope);
    final updated = update(current);
    await writeSettings(updated, scope);
  }

  /// Update settings synchronously.
  void updateSettingsSync(
    SettingsScope scope,
    ClaudeSettings Function(ClaudeSettings current) update,
  ) {
    final current = readSettingsSync(scope);
    final updated = update(current);
    writeSettingsSync(updated, scope);
  }

  // ============================================
  // Convenience Methods
  // ============================================

  /// Check if an MCP server is enabled.
  ///
  /// Checks all scopes and the enableAllProjectMcpServers flag.
  bool isMcpServerEnabled(String serverName) {
    final settings = readMergedSettingsSync();

    // Check if explicitly disabled
    if (settings.disabledMcpjsonServers?.contains(serverName) ?? false) {
      return false;
    }

    // Check if all project servers are enabled
    if (settings.enableAllProjectMcpServers == true) {
      return true;
    }

    // Check if explicitly enabled
    return settings.enabledMcpjsonServers?.contains(serverName) ?? false;
  }

  /// Enable an MCP server in local settings.
  Future<void> enableMcpServer(String serverName) async {
    await updateSettings(SettingsScope.local, (current) {
      final enabled = current.enabledMcpjsonServers ?? [];
      if (enabled.contains(serverName)) return current;

      return current.copyWith(enabledMcpjsonServers: [...enabled, serverName]);
    });
  }

  /// Enable multiple MCP servers in local settings.
  Future<void> enableMcpServers(List<String> serverNames) async {
    await updateSettings(SettingsScope.local, (current) {
      final enabled = current.enabledMcpjsonServers ?? [];
      final newServers = serverNames.where((s) => !enabled.contains(s));

      if (newServers.isEmpty) return current;

      return current.copyWith(
        enabledMcpjsonServers: [...enabled, ...newServers],
      );
    });
  }

  /// Disable an MCP server in local settings.
  Future<void> disableMcpServer(String serverName) async {
    await updateSettings(SettingsScope.local, (current) {
      final enabled = current.enabledMcpjsonServers ?? [];
      if (!enabled.contains(serverName)) return current;

      return current.copyWith(
        enabledMcpjsonServers: enabled.where((s) => s != serverName).toList(),
      );
    });
  }

  /// Add a permission pattern to the allow list.
  Future<void> addToAllowList(String pattern) async {
    await updateSettings(SettingsScope.local, (current) {
      final permissions = current.permissions;
      final allow = permissions?.allow ?? [];

      if (allow.contains(pattern)) return current;

      return current.copyWith(
        permissions: (permissions ?? const PermissionsConfig()).copyWith(
          allow: [...allow, pattern],
        ),
      );
    });
  }

  /// Add a permission pattern to the deny list.
  Future<void> addToDenyList(String pattern) async {
    await updateSettings(SettingsScope.local, (current) {
      final permissions = current.permissions;
      final deny = permissions?.deny ?? [];

      if (deny.contains(pattern)) return current;

      return current.copyWith(
        permissions: (permissions ?? const PermissionsConfig()).copyWith(
          deny: [...deny, pattern],
        ),
      );
    });
  }

  /// Get list of all unapproved MCP servers from .mcp.json.
  Future<List<String>> getUnapprovedMcpServers() async {
    final mcpJson = await readMcpJson();
    final settings = await readMergedSettings();

    if (settings.enableAllProjectMcpServers == true) {
      return [];
    }

    final enabled = settings.enabledMcpjsonServers ?? [];
    return mcpJson.serverNames
        .where((name) => !enabled.contains(name))
        .toList();
  }

  /// Check if all MCP servers from .mcp.json are approved.
  bool areAllMcpServersApprovedSync() {
    final mcpJson = readMcpJsonSync();
    if (mcpJson.serverNames.isEmpty) return true;

    final settings = readMergedSettingsSync();

    if (settings.enableAllProjectMcpServers == true) {
      return true;
    }

    final enabled = settings.enabledMcpjsonServers ?? [];
    return mcpJson.serverNames.every((name) => enabled.contains(name));
  }

  // ============================================
  // Private Helpers
  // ============================================

  Future<ClaudeSettings> _readSettingsFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return ClaudeSettings.empty();
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ClaudeSettings.fromJson(json);
    } catch (e) {
      // Return empty settings on parse error
      return ClaudeSettings.empty();
    }
  }

  ClaudeSettings _readSettingsFileSync(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return ClaudeSettings.empty();
    }

    try {
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ClaudeSettings.fromJson(json);
    } catch (e) {
      return ClaudeSettings.empty();
    }
  }

  Future<McpJsonConfig> _readMcpJsonFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return const McpJsonConfig();
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return McpJsonConfig.fromJson(json);
    } catch (e) {
      return const McpJsonConfig();
    }
  }

  McpJsonConfig _readMcpJsonFileSync(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return const McpJsonConfig();
    }

    try {
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return McpJsonConfig.fromJson(json);
    } catch (e) {
      return const McpJsonConfig();
    }
  }

  Future<void> _writeSettingsFile(String path, ClaudeSettings settings) async {
    final file = File(path);

    // Ensure parent directory exists
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    // Write to temp file first for atomic operation
    final tempFile = File('$path.tmp');
    final encoder = const JsonEncoder.withIndent('  ');
    await tempFile.writeAsString(encoder.convert(settings.toJson()));

    // Atomic rename
    await tempFile.rename(path);
  }

  void _writeSettingsFileSync(String path, ClaudeSettings settings) {
    final file = File(path);

    // Ensure parent directory exists
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    // Write to temp file first for atomic operation
    final tempFile = File('$path.tmp');
    final encoder = const JsonEncoder.withIndent('  ');
    tempFile.writeAsStringSync(encoder.convert(settings.toJson()));

    // Atomic rename
    tempFile.renameSync(path);
  }
}
