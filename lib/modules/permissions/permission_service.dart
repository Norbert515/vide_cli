import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';
import '../settings/local_settings_manager.dart';
import '../settings/permission_matcher.dart';
import '../settings/pattern_inference.dart';
import '../settings/gitignore_matcher.dart';

// =============================================================================
// Data Classes
// =============================================================================

/// Permission request from Claude Code hook
class PermissionRequest {
  final String requestId;
  final String toolName;
  final Map<String, dynamic> toolInput;
  final String cwd;
  final DateTime timestamp;
  final String? inferredPattern;

  PermissionRequest({
    required this.requestId,
    required this.toolName,
    required this.toolInput,
    required this.cwd,
    DateTime? timestamp,
    this.inferredPattern,
  }) : timestamp = timestamp ?? DateTime.now();

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      requestId: '',
      toolName: json['tool_name'] as String,
      toolInput: json['tool_input'] as Map<String, dynamic>,
      cwd: json['cwd'] as String,
    );
  }

  PermissionRequest copyWith({String? requestId, String? inferredPattern}) {
    return PermissionRequest(
      requestId: requestId ?? this.requestId,
      toolName: toolName,
      toolInput: toolInput,
      cwd: cwd,
      timestamp: timestamp,
      inferredPattern: inferredPattern ?? this.inferredPattern,
    );
  }

  String get displayAction {
    switch (toolName) {
      case 'Bash':
        return 'Run: ${toolInput['command']}';
      case 'Write':
        return 'Write: ${toolInput['file_path']}';
      case 'Edit':
        return 'Edit: ${toolInput['file_path']}';
      case 'MultiEdit':
        return 'MultiEdit: ${toolInput['file_path']}';
      case 'WebFetch':
        return 'Fetch: ${toolInput['url']}';
      case 'WebSearch':
        return 'Search: ${toolInput['query']}';
      default:
        return 'Use $toolName';
    }
  }
}

/// Permission response to Claude Code hook
class PermissionResponse {
  final String decision;
  final String? reason;
  final bool remember;

  PermissionResponse({required this.decision, this.reason, required this.remember});

  Map<String, dynamic> toJson() => {'decision': decision, if (reason != null) 'reason': reason, 'remember': remember};
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final service = PermissionService();
  ref.onDispose(() => service.dispose());
  return service;
});

class PermissionService {
  HttpServer? _server;
  int? _port;
  String? _primarySessionId;
  GitignoreMatcher? _gitignoreMatcher;
  String? _permissionMode;

  // Track all registered session IDs and their files
  final Set<String> _registeredSessionIds = {};
  final List<File> _portFiles = [];
  final List<File> _pidFiles = [];
  final List<File> _modeFiles = [];

  final _requestController = StreamController<PermissionRequest>.broadcast();
  final Map<String, Completer<PermissionResponse>> _pendingRequests = {};

  // Session cache (patterns approved during execution)
  final Set<String> _sessionCache = {};

  /// Stream of permission requests for the UI
  Stream<PermissionRequest> get requests => _requestController.stream;

  /// Whether the server is running
  bool get isRunning => _server != null;

  /// Start the permission server for a session
  Future<void> start({required String sessionId, String? permissionMode}) async {
    if (_server != null) {
      await stop();
    }

    _primarySessionId = sessionId;
    _permissionMode = permissionMode ?? 'acceptEdits';
    _port = await _findAvailablePort();
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port!);

    // Write files for the primary session
    await _writeFilesForSession(sessionId);
    _registeredSessionIds.add(sessionId);

    _server!.listen(_handleRequest);
  }

  /// Register an additional session ID (for sub-agents)
  /// This creates port/pid/mode files so hooks from this session can find the server
  Future<void> registerAdditionalSession(String sessionId) async {
    if (_server == null || _port == null) {
      return;
    }

    if (_registeredSessionIds.contains(sessionId)) {
      return;
    }

    await _writeFilesForSession(sessionId);
    _registeredSessionIds.add(sessionId);
  }

  /// Write port/pid/mode files for a session ID
  Future<void> _writeFilesForSession(String sessionId) async {
    final portFile = File('${Directory.systemTemp.path}/vide_hook_port_$sessionId');
    await portFile.writeAsString(_port.toString());
    _portFiles.add(portFile);

    final pidFile = File('${Directory.systemTemp.path}/vide_hook_pid_$sessionId');
    await pidFile.writeAsString(pid.toString());
    _pidFiles.add(pidFile);

    if (_permissionMode != null) {
      final modeFile = File('${Directory.systemTemp.path}/vide_hook_mode_$sessionId');
      await modeFile.writeAsString(_permissionMode!);
      _modeFiles.add(modeFile);
    }
  }

  /// Stop the permission server
  Future<void> stop() async {
    await _server?.close();
    _server = null;

    // Delete all port files
    for (final file in _portFiles) {
      if (await file.exists()) {
        await file.delete();
      }
    }
    _portFiles.clear();

    // Delete all pid files
    for (final file in _pidFiles) {
      if (await file.exists()) {
        await file.delete();
      }
    }
    _pidFiles.clear();

    // Delete all mode files
    for (final file in _modeFiles) {
      if (await file.exists()) {
        await file.delete();
      }
    }
    _modeFiles.clear();

    _registeredSessionIds.clear();
    _sessionCache.clear();
    _gitignoreMatcher = null;
  }

  Future<int> _findAvailablePort() async {
    for (var i = 0; i < 10; i++) {
      final port = 50000 + (DateTime.now().millisecondsSinceEpoch % 10000);
      try {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
        await server.close();
        return port;
      } catch (e) {
        // Port in use, try next
      }
    }
    throw Exception('Could not find available port');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method == 'POST' && request.uri.path == '/permission') {
      await _handlePermissionRequest(request);
    } else {
      request.response
        ..statusCode = 404
        ..write('Not Found')
        ..close();
    }
  }

  Future<void> _handlePermissionRequest(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final hookRequest = PermissionRequest.fromJson(data);
      final requestId = const Uuid().v4();

      // Load settings
      final settingsManager = LocalSettingsManager(projectRoot: hookRequest.cwd, parrottRoot: hookRequest.cwd);
      final settings = await settingsManager.readSettings();

      // Load gitignore if needed
      if (_gitignoreMatcher == null) {
        try {
          _gitignoreMatcher = await GitignoreMatcher.load(hookRequest.cwd);
        } catch (e) {
          // Ignore gitignore load errors
        }
      }

      // Check gitignore for Read operations
      if (hookRequest.toolName == 'Read') {
        final filePath = hookRequest.toolInput['file_path'] as String?;
        if (filePath != null && _gitignoreMatcher != null && _gitignoreMatcher!.shouldIgnore(filePath)) {
          request.response
            ..statusCode = 200
            ..write(jsonEncode({'decision': 'deny', 'reason': 'Blocked by .gitignore', 'remember': false}))
            ..close();
          return;
        }
      }

      // Hardcoded deny list for problematic MCP tools
      const hardcodedDenyList = [
        'mcp__dart__analyze_files', // Floods context with too much output (all lint hints, no filtering)
      ];

      if (hardcodedDenyList.contains(hookRequest.toolName)) {
        request.response
          ..statusCode = 200
          ..write(jsonEncode({
            'decision': 'deny',
            'reason': 'Blocked: ${hookRequest.toolName} floods context with too much output. Use `dart analyze` via Bash instead.',
            'remember': false,
          }))
          ..close();
        return;
      }

      // Auto-approve all vide MCP tools, TodoWrite, and safe internal tools
      if (hookRequest.toolName.startsWith('mcp__vide-') ||
          hookRequest.toolName.startsWith('mcp__flutter-runtime__') ||
          hookRequest.toolName == 'TodoWrite' ||
          hookRequest.toolName == 'BashOutput' ||
          hookRequest.toolName == 'KillShell' ||
          hookRequest.toolName == 'KillBash') {
        request.response
          ..statusCode = 200
          ..write(jsonEncode({
            'decision': 'allow',
            'reason': 'Auto-approved internal tool',
            'remember': false,
          }))
          ..close();
        return;
      }

      // Check deny list (highest priority)
      for (final pattern in settings.permissions.deny) {
        if (PermissionMatcher.matches(
          pattern,
          hookRequest.toolName,
          hookRequest.toolInput,
          context: {'cwd': hookRequest.cwd},
        )) {
          request.response
            ..statusCode = 200
            ..write(jsonEncode({'decision': 'deny', 'reason': 'Blocked by deny list', 'remember': false}))
            ..close();
          return;
        }
      }

      // Check safe bash commands (auto-approve read-only)
      if (hookRequest.toolName == 'Bash') {
        if (PermissionMatcher.isSafeBashCommand(hookRequest.toolInput, {'cwd': hookRequest.cwd})) {
          request.response
            ..statusCode = 200
            ..write(
              jsonEncode({'decision': 'allow', 'reason': 'Auto-approved safe read-only command', 'remember': false}),
            )
            ..close();
          return;
        }
      }

      // Check session cache (for Write/Edit/MultiEdit)
      if (isAllowedBySessionCache(hookRequest.toolName, hookRequest.toolInput)) {
        request.response
          ..statusCode = 200
          ..write(jsonEncode({'decision': 'allow', 'reason': 'Auto-approved from session cache', 'remember': false}))
          ..close();
        return;
      }

      // Check allow list
      for (final pattern in settings.permissions.allow) {
        if (PermissionMatcher.matches(
          pattern,
          hookRequest.toolName,
          hookRequest.toolInput,
          context: {'cwd': hookRequest.cwd},
        )) {
          request.response
            ..statusCode = 200
            ..write(jsonEncode({'decision': 'allow', 'reason': 'Auto-approved from allow list', 'remember': false}))
            ..close();
          return;
        }
      }

      // Create completer for user response
      final completer = Completer<PermissionResponse>();
      _pendingRequests[requestId] = completer;

      // Infer pattern for "remember" display
      final inferredPattern = PatternInference.inferPattern(hookRequest.toolName, hookRequest.toolInput);

      // Emit request to UI
      _requestController.add(hookRequest.copyWith(requestId: requestId, inferredPattern: inferredPattern));

      // Wait for response
      final response = await completer.future;

      request.response
        ..statusCode = 200
        ..write(jsonEncode(response.toJson()))
        ..close();

      _pendingRequests.remove(requestId);
    } catch (e) {
      request.response
        ..statusCode = 500
        ..write(jsonEncode({'error': 'Internal server error', 'details': '$e'}))
        ..close();
    }
  }

  /// Respond to a permission request
  void respondToPermission(String requestId, PermissionResponse response) {
    _pendingRequests[requestId]?.complete(response);
  }

  /// Check if allowed by session cache
  bool isAllowedBySessionCache(String toolName, Map<String, dynamic> toolInput) {
    if (!_isWriteOperation(toolName)) return false;

    for (final pattern in _sessionCache) {
      if (PermissionMatcher.matches(pattern, toolName, toolInput)) {
        return true;
      }
    }
    return false;
  }

  /// Add a pattern to session cache
  void addSessionPattern(String pattern) {
    _sessionCache.add(pattern);
  }

  /// Clear session cache
  void clearSessionCache() {
    _sessionCache.clear();
  }

  bool _isWriteOperation(String toolName) {
    return toolName == 'Write' || toolName == 'Edit' || toolName == 'MultiEdit';
  }

  /// Clean up stale hook files from previous sessions (call on app startup)
  static Future<void> cleanupStaleFiles() async {
    try {
      final tempDir = Directory(Directory.systemTemp.path);
      final files = await tempDir
          .list()
          .where(
            (f) =>
                f.path.contains('vide_hook_port_') ||
                f.path.contains('vide_hook_pid_') ||
                f.path.contains('vide_hook_mode_'),
          )
          .toList();

      for (final file in files) {
        if (file is File) {
          final match = RegExp(r'vide_hook_(port|pid|mode)_(.+)$').firstMatch(file.path);

          if (match != null) {
            final sessionId = match.group(2)!;
            final pidFile = File('${Directory.systemTemp.path}/vide_hook_pid_$sessionId');
            final portFile = File('${Directory.systemTemp.path}/vide_hook_port_$sessionId');
            final modeFile = File('${Directory.systemTemp.path}/vide_hook_mode_$sessionId');

            if (await pidFile.exists()) {
              final pidString = await pidFile.readAsString();
              final processPid = int.tryParse(pidString.trim());

              if (processPid != null && !await _isProcessAlive(processPid)) {
                await portFile.delete().catchError((_) => portFile);
                await pidFile.delete().catchError((_) => pidFile);
                await modeFile.delete().catchError((_) => modeFile);
              }
            } else {
              await file.delete().catchError((_) => file);
            }
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  static Future<bool> _isProcessAlive(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('tasklist', ['/FI', 'PID eq $pid']);
        return result.stdout.toString().contains(pid.toString());
      } else {
        final result = await Process.run('kill', ['-0', pid.toString()]);
        return result.exitCode == 0;
      }
    } catch (e) {
      return false;
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await stop();
    await _requestController.close();
  }
}
