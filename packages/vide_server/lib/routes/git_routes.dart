/// Git operation routes for the REST API.
///
/// Provides endpoints to query and mutate git repositories.
/// All operations are restricted to paths within the configured
/// filesystem root to prevent path traversal attacks.
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:vide_core/vide_core.dart' show GitService;

import '../services/server_config.dart';

final _log = Logger('GitRoutes');

// =============================================================================
// Read operations (GET)
// =============================================================================

/// GET /api/v1/git/status?path=...&detailed=true
Future<Response> gitStatus(Request request, ServerConfig config) async {
  final repoPath = _requirePath(request, config);
  if (repoPath == null) return _pathError(request, config);

  final detailed =
      request.url.queryParameters['detailed']?.toLowerCase() == 'true';

  try {
    final git = GitService(workingDirectory: repoPath);
    final status = await git.status(detailed: detailed);

    return _ok({
      'branch': status.branch,
      'has-changes': status.hasChanges,
      'modified-files': status.modifiedFiles,
      'untracked-files': status.untrackedFiles,
      'staged-files': status.stagedFiles,
      'ahead': status.ahead,
      'behind': status.behind,
    });
  } catch (e) {
    return _gitError('status', e);
  }
}

/// GET /api/v1/git/branches?path=...&all=false
Future<Response> gitBranches(Request request, ServerConfig config) async {
  final repoPath = _requirePath(request, config);
  if (repoPath == null) return _pathError(request, config);

  final all = request.url.queryParameters['all']?.toLowerCase() == 'true';

  try {
    final git = GitService(workingDirectory: repoPath);
    final branches = await git.branches(all: all);

    return _ok({
      'branches': branches
          .map(
            (b) => {
              'name': b.name,
              'is-current': b.isCurrent,
              'is-remote': b.isRemote,
              if (b.upstream != null) 'upstream': b.upstream,
              'last-commit': b.lastCommit,
            },
          )
          .toList(),
    });
  } catch (e) {
    return _gitError('branches', e);
  }
}

/// GET /api/v1/git/log?path=...&count=10
Future<Response> gitLog(Request request, ServerConfig config) async {
  final repoPath = _requirePath(request, config);
  if (repoPath == null) return _pathError(request, config);

  final count = int.tryParse(request.url.queryParameters['count'] ?? '') ?? 10;

  try {
    final git = GitService(workingDirectory: repoPath);
    final commits = await git.log(count: count);

    return _ok({
      'commits': commits
          .map(
            (c) => {
              'hash': c.hash,
              'author': c.author,
              'message': c.message,
              'date': c.date.toIso8601String(),
            },
          )
          .toList(),
    });
  } catch (e) {
    return _gitError('log', e);
  }
}

/// GET /api/v1/git/diff?path=...&staged=false
Future<Response> gitDiff(Request request, ServerConfig config) async {
  final repoPath = _requirePath(request, config);
  if (repoPath == null) return _pathError(request, config);

  final staged = request.url.queryParameters['staged']?.toLowerCase() == 'true';

  try {
    final git = GitService(workingDirectory: repoPath);
    final result = await git.diff(staged: staged);

    return _ok({'diff': result});
  } catch (e) {
    return _gitError('diff', e);
  }
}

/// GET /api/v1/git/worktrees?path=...
Future<Response> gitWorktrees(Request request, ServerConfig config) async {
  final repoPath = _requirePath(request, config);
  if (repoPath == null) return _pathError(request, config);

  try {
    final git = GitService(workingDirectory: repoPath);
    final worktrees = await git.worktrees();

    return _ok({
      'worktrees': worktrees
          .map(
            (w) => {
              'path': w.path,
              'branch': w.branch,
              'commit': w.commit,
              'is-locked': w.isLocked,
              if (w.lockReason != null) 'lock-reason': w.lockReason,
            },
          )
          .toList(),
    });
  } catch (e) {
    return _gitError('worktrees', e);
  }
}

/// GET /api/v1/git/stash/list?path=...
Future<Response> gitStashList(Request request, ServerConfig config) async {
  final repoPath = _requirePath(request, config);
  if (repoPath == null) return _pathError(request, config);

  try {
    final git = GitService(workingDirectory: repoPath);
    final result = await git.stashList();

    return _ok({'stashes': result});
  } catch (e) {
    return _gitError('stash-list', e);
  }
}

// =============================================================================
// Write operations (POST)
// =============================================================================

/// POST /api/v1/git/commit { "path": "...", "message": "...", "all": false, "amend": false }
Future<Response> gitCommit(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  final message = json['message'] as String?;
  if (message == null || message.isEmpty) {
    return _badRequest('message is required');
  }

  final all = json['all'] as bool? ?? false;
  final amend = json['amend'] as bool? ?? false;

  try {
    final git = GitService(workingDirectory: repoPath);
    await git.commit(message, all: all, amend: amend);

    return _ok({'status': 'committed'});
  } catch (e) {
    return _gitError('commit', e);
  }
}

/// POST /api/v1/git/stage { "path": "...", "files": ["file1", "file2"] }
Future<Response> gitStage(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  final files = (json['files'] as List?)?.cast<String>();
  if (files == null || files.isEmpty) {
    return _badRequest('files is required');
  }

  try {
    final git = GitService(workingDirectory: repoPath);
    await git.stage(files);

    return _ok({'status': 'staged', 'files': files});
  } catch (e) {
    return _gitError('stage', e);
  }
}

/// POST /api/v1/git/checkout { "path": "...", "branch": "...", "create": false }
Future<Response> gitCheckout(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  final branch = json['branch'] as String?;
  if (branch == null || branch.isEmpty) {
    return _badRequest('branch is required');
  }

  final create = json['create'] as bool? ?? false;

  try {
    final git = GitService(workingDirectory: repoPath);
    if (create) {
      final fromBranch = json['from-branch'] as String?;
      await git.createAndCheckoutBranch(branch, fromBranch: fromBranch);
    } else {
      await git.checkout(branch);
    }

    return _ok({'status': 'checked-out', 'branch': branch});
  } catch (e) {
    return _gitError('checkout', e);
  }
}

/// POST /api/v1/git/push { "path": "...", "remote": "origin", "branch": "...", "set-upstream": false }
Future<Response> gitPush(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  final remote = json['remote'] as String? ?? 'origin';
  final branch = json['branch'] as String?;
  final setUpstream = json['set-upstream'] as bool? ?? false;

  try {
    final git = GitService(workingDirectory: repoPath);
    final result = await git.push(
      remote: remote,
      branch: branch,
      setUpstream: setUpstream,
    );

    return _ok({'status': 'pushed', 'output': result});
  } catch (e) {
    return _gitError('push', e);
  }
}

/// POST /api/v1/git/pull { "path": "...", "remote": "origin", "branch": "...", "rebase": false }
Future<Response> gitPull(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  final remote = json['remote'] as String? ?? 'origin';
  final branch = json['branch'] as String?;
  final rebase = json['rebase'] as bool? ?? false;

  try {
    final git = GitService(workingDirectory: repoPath);
    final result = await git.pull(
      remote: remote,
      branch: branch,
      rebase: rebase,
    );

    return _ok({'status': 'pulled', 'output': result});
  } catch (e) {
    return _gitError('pull', e);
  }
}

/// POST /api/v1/git/fetch { "path": "...", "remote": "origin", "all": false, "prune": false }
Future<Response> gitFetch(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  final remote = json['remote'] as String? ?? 'origin';
  final all = json['all'] as bool? ?? false;
  final prune = json['prune'] as bool? ?? false;

  try {
    final git = GitService(workingDirectory: repoPath);
    await git.fetch(remote: remote, all: all, prune: prune);

    return _ok({'status': 'fetched'});
  } catch (e) {
    return _gitError('fetch', e);
  }
}

/// POST /api/v1/git/sync { "path": "..." }
Future<Response> gitSync(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  try {
    final git = GitService(workingDirectory: repoPath);
    await git.sync();

    return _ok({'status': 'synced'});
  } catch (e) {
    return _gitError('sync', e);
  }
}

/// POST /api/v1/git/merge { "path": "...", "branch": "...", "message": "...", "no-commit": false, "abort": false }
Future<Response> gitMerge(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  final abort = json['abort'] as bool? ?? false;

  try {
    final git = GitService(workingDirectory: repoPath);

    if (abort) {
      await git.mergeAbort();
      return _ok({'status': 'merge-aborted'});
    }

    final branch = json['branch'] as String?;
    if (branch == null || branch.isEmpty) {
      return _badRequest('branch is required for merge');
    }

    final message = json['message'] as String?;
    final noCommit = json['no-commit'] as bool? ?? false;

    await git.merge(branch, message: message, noCommit: noCommit);

    return _ok({'status': 'merged'});
  } catch (e) {
    return _gitError('merge', e);
  }
}

/// POST /api/v1/git/stash { "path": "...", "action": "save|pop|apply|drop|clear", ... }
Future<Response> gitStash(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  final action = json['action'] as String? ?? 'save';

  try {
    final git = GitService(workingDirectory: repoPath);

    switch (action) {
      case 'save':
        final message = json['message'] as String?;
        await git.stash(message: message);
        return _ok({'status': 'stash-saved'});
      case 'pop':
        final index = json['index'] as int?;
        await git.stashPop(index: index);
        return _ok({'status': 'stash-popped'});
      case 'apply':
        final index = json['index'] as int?;
        await git.stashApply(index: index);
        return _ok({'status': 'stash-applied'});
      case 'drop':
        final index = json['index'] as int?;
        await git.stashDrop(index: index);
        return _ok({'status': 'stash-dropped'});
      case 'clear':
        await git.stashClear();
        return _ok({'status': 'stash-cleared'});
      default:
        return _badRequest('Unknown stash action: $action');
    }
  } catch (e) {
    return _gitError('stash', e);
  }
}

/// POST /api/v1/git/worktree/add { "path": "...", "branch": "...", "create-branch": false, "base-branch": "..." }
Future<Response> gitWorktreeAdd(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  final branch = json['branch'] as String?;
  if (branch == null || branch.isEmpty) {
    return _badRequest('branch is required');
  }

  final createBranch = json['create-branch'] as bool? ?? false;
  final baseBranch = json['base-branch'] as String?;

  try {
    final git = GitService(workingDirectory: repoPath);
    final worktreePath = await git.createWorktree(
      branch,
      baseBranch: baseBranch,
      createBranch: createBranch,
    );

    return _ok({'status': 'worktree-added', 'worktree-path': worktreePath});
  } catch (e) {
    return _gitError('worktree-add', e);
  }
}

/// POST /api/v1/git/worktree/remove { "path": "...", "worktree": "...", "force": false }
Future<Response> gitWorktreeRemove(Request request, ServerConfig config) async {
  final json = await _parseJson(request);
  if (json == null) return _invalidJson();

  final repoPath = _requirePathFromBody(json, config);
  if (repoPath == null) return _pathBodyError(json, config);

  final worktree = json['worktree'] as String?;
  if (worktree == null || worktree.isEmpty) {
    return _badRequest('worktree is required');
  }

  final force = json['force'] as bool? ?? false;

  try {
    final git = GitService(workingDirectory: repoPath);
    await git.removeWorktree(worktree, force: force);

    return _ok({'status': 'worktree-removed'});
  } catch (e) {
    return _gitError('worktree-remove', e);
  }
}

// =============================================================================
// Helpers
// =============================================================================

/// Validate and extract the `path` query parameter.
/// Returns null if the path is missing or outside the filesystem root.
String? _requirePath(Request request, ServerConfig config) {
  final pathParam = request.url.queryParameters['path'];
  if (pathParam == null || pathParam.trim().isEmpty) return null;

  final rootPath = p.canonicalize(config.filesystemRoot);
  final canonicalPath = p.canonicalize(pathParam);

  if (!_isWithinRoot(canonicalPath, rootPath)) {
    _log.warning('Path traversal attempt: $canonicalPath outside $rootPath');
    return null;
  }

  return canonicalPath;
}

/// Validate and extract the `path` field from a JSON body.
String? _requirePathFromBody(Map<String, dynamic> json, ServerConfig config) {
  final pathParam = json['path'] as String?;
  if (pathParam == null || pathParam.trim().isEmpty) return null;

  final rootPath = p.canonicalize(config.filesystemRoot);
  final canonicalPath = p.canonicalize(pathParam);

  if (!_isWithinRoot(canonicalPath, rootPath)) {
    _log.warning('Path traversal attempt: $canonicalPath outside $rootPath');
    return null;
  }

  return canonicalPath;
}

bool _isWithinRoot(String path, String root) {
  final normalizedPath = p.normalize(path);
  final normalizedRoot = p.normalize(root);
  return normalizedPath == normalizedRoot ||
      normalizedPath.startsWith('$normalizedRoot${p.separator}');
}

Response _pathError(Request request, ServerConfig config) {
  final pathParam = request.url.queryParameters['path'];
  if (pathParam == null || pathParam.trim().isEmpty) {
    return _badRequest('path query parameter is required');
  }
  return Response.forbidden(
    jsonEncode({
      'error': 'Path is outside allowed filesystem root',
      'code': 'PATH_TRAVERSAL',
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

Response _pathBodyError(Map<String, dynamic> json, ServerConfig config) {
  final pathParam = json['path'] as String?;
  if (pathParam == null || pathParam.trim().isEmpty) {
    return _badRequest('path is required');
  }
  return Response.forbidden(
    jsonEncode({
      'error': 'Path is outside allowed filesystem root',
      'code': 'PATH_TRAVERSAL',
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Map<String, dynamic>?> _parseJson(Request request) async {
  try {
    final body = await request.readAsString();
    return jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    _log.warning('Invalid JSON in git request: $e');
    return null;
  }
}

Response _ok(Map<String, dynamic> data) {
  return Response.ok(
    jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}

Response _badRequest(String message) {
  return Response.badRequest(
    body: jsonEncode({'error': message, 'code': 'INVALID_REQUEST'}),
    headers: {'Content-Type': 'application/json'},
  );
}

Response _invalidJson() {
  return _badRequest('Invalid JSON body');
}

Response _gitError(String operation, Object error) {
  _log.warning('Git $operation failed: $error');
  return Response.internalServerError(
    body: jsonEncode({
      'error': error.toString(),
      'code': 'GIT_ERROR',
      'operation': operation,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
