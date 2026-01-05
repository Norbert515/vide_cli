import 'dart:async';
import 'dart:io';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:claude_sdk/claude_sdk.dart';
import 'package:sentry/sentry.dart';
import '../../../models/agent_id.dart';
import 'git_client.dart';
import 'package:riverpod/riverpod.dart';
import 'git_models.dart';

final gitServerProvider = Provider.family<GitServer, AgentId>((ref, agentId) {
  return GitServer();
});

/// MCP server for Git operations including worktrees
class GitServer extends McpServerBase {
  static const String serverName = 'vide-git';

  final _statusStream = StreamController<GitStatus>.broadcast();

  /// Stream of git status updates
  Stream<GitStatus> get statusUpdates => _statusStream.stream;

  GitServer() : super(name: serverName, version: '1.0.0');

  /// Report a git operation error to Sentry with context
  Future<void> _reportError(
    Object e,
    StackTrace stackTrace,
    String toolName, {
    Map<String, dynamic>? context,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setTag('mcp_server', serverName);
      scope.setTag('mcp_tool', toolName);
      if (context != null) {
        scope.setContexts('mcp_context', context);
      }
    });
    await Sentry.captureException(e, stackTrace: stackTrace);
  }

  @override
  List<String> get toolNames => [
    'gitStatus',
    'gitCommit',
    'gitAdd',
    'gitDiff',
    'gitLog',
    'gitBranch',
    'gitCheckout',
    'gitStash',
    'gitWorktreeList',
    'gitWorktreeAdd',
    'gitWorktreeRemove',
    'gitWorktreeLock',
    'gitWorktreeUnlock',
    'gitFetch',
    'gitPull',
    'gitMerge',
    'gitRebase',
  ];

  @override
  void registerTools(McpServer server) {
    // Git Status
    server.tool(
      'gitStatus',
      description: 'Get current git repository status',
      toolInputSchema: ToolInputSchema(
        properties: {
          'path': {
            'type': 'string',
            'description': 'Repository path (defaults to current directory)',
          },
          'detailed': {
            'type': 'boolean',
            'description': 'Include detailed file status',
            'default': false,
          },
        },
      ),
      callback: ({args, extra}) async {
        final path = args?['path'] as String? ?? Directory.current.path;
        final detailed = args?['detailed'] as bool? ?? false;

        try {
          final git = GitClient(workingDirectory: path);
          final status = await git.status(detailed: detailed);

          if (detailed) {
            final diffResult = await git.diff(staged: false);
            return CallToolResult.fromContent(
              content: [
                TextContent(
                  text:
                      '''
Git Status:
  Branch: ${status.branch}
  Modified: ${status.modifiedFiles.length} files
  Untracked: ${status.untrackedFiles.length} files
  Staged: ${status.stagedFiles.length} files
  Ahead: ${status.ahead}, Behind: ${status.behind}

${diffResult.isEmpty ? 'No changes' : diffResult}
''',
                ),
              ],
            );
          }

          _statusStream.add(status);

          return CallToolResult.fromContent(
            content: [
              TextContent(
                text: 'Branch: ${status.branch}, Changes: ${status.hasChanges}',
              ),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(e, stackTrace, 'gitStatus');
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Commit
    server.tool(
      'gitCommit',
      description: 'Create a git commit',
      toolInputSchema: ToolInputSchema(
        properties: {
          'message': {'type': 'string', 'description': 'Commit message'},
          'path': {'type': 'string', 'description': 'Repository path'},
          'all': {
            'type': 'boolean',
            'description': 'Stage all changes before commit',
            'default': false,
          },
          'amend': {
            'type': 'boolean',
            'description': 'Amend the previous commit',
            'default': false,
          },
        },
        required: ['message'],
      ),
      callback: ({args, extra}) async {
        final message = args!['message'] as String;
        final path = args['path'] as String? ?? Directory.current.path;
        final all = args['all'] as bool? ?? false;
        final amend = args['amend'] as bool? ?? false;

        try {
          final git = GitClient(workingDirectory: path);
          await git.commit(message, all: all, amend: amend);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Commit created')],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitCommit',
            context: {'amend': amend, 'all': all},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Add
    server.tool(
      'gitAdd',
      description: 'Stage files for commit',
      toolInputSchema: ToolInputSchema(
        properties: {
          'files': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Files to stage (use "." for all)',
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
        required: ['files'],
      ),
      callback: ({args, extra}) async {
        final files = (args!['files'] as List).cast<String>();
        final path = args['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          await git.add(files);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Files staged: ${files.join(", ")}')],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitAdd',
            context: {'file_count': files.length},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Diff
    server.tool(
      'gitDiff',
      description: 'Show changes in files',
      toolInputSchema: ToolInputSchema(
        properties: {
          'staged': {
            'type': 'boolean',
            'description': 'Show staged changes',
            'default': false,
          },
          'files': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Specific files to diff',
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
      ),
      callback: ({args, extra}) async {
        final staged = args?['staged'] as bool? ?? false;
        final files = (args?['files'] as List?)?.cast<String>() ?? [];
        final path = args?['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          final result = await git.diff(staged: staged, files: files);
          return CallToolResult.fromContent(
            content: [
              TextContent(text: result.isEmpty ? 'No changes' : result),
            ],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitDiff',
            context: {'staged': staged},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Log
    server.tool(
      'gitLog',
      description: 'Show commit history',
      toolInputSchema: ToolInputSchema(
        properties: {
          'count': {
            'type': 'integer',
            'description': 'Number of commits to show',
            'default': 10,
          },
          'oneline': {
            'type': 'boolean',
            'description': 'Show in oneline format',
            'default': true,
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
      ),
      callback: ({args, extra}) async {
        final count = args?['count'] as int? ?? 10;
        final oneline = args?['oneline'] as bool? ?? true;
        final path = args?['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          if (oneline) {
            final result = await git.runCommand([
              'log',
              '-n',
              count.toString(),
              '--oneline',
            ]);
            return CallToolResult.fromContent(
              content: [TextContent(text: result)],
            );
          } else {
            final commits = await git.log(count: count);
            final result = commits
                .map((c) => '${c.hash}|${c.author}|${c.message}|${c.date}')
                .join('\n');
            return CallToolResult.fromContent(
              content: [TextContent(text: result)],
            );
          }
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitLog',
            context: {'count': count, 'oneline': oneline},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Branch
    server.tool(
      'gitBranch',
      description: 'List or create branches',
      toolInputSchema: ToolInputSchema(
        properties: {
          'create': {
            'type': 'string',
            'description': 'Name of branch to create',
          },
          'delete': {
            'type': 'string',
            'description': 'Name of branch to delete',
          },
          'all': {
            'type': 'boolean',
            'description': 'Show all branches including remotes',
            'default': false,
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
      ),
      callback: ({args, extra}) async {
        final create = args?['create'] as String?;
        final delete = args?['delete'] as String?;
        final all = args?['all'] as bool? ?? false;
        final path = args?['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          if (create != null) {
            await git.createBranch(create);
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Branch created: $create')],
            );
          } else if (delete != null) {
            await git.deleteBranch(delete);
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Branch deleted: $delete')],
            );
          } else {
            final branches = await git.branches(all: all);
            final result = branches
                .map((b) => '${b.isCurrent ? "* " : "  "}${b.name}')
                .join('\n');
            return CallToolResult.fromContent(
              content: [TextContent(text: result)],
            );
          }
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitBranch',
            context: {
              'operation': create != null
                  ? 'create'
                  : (delete != null ? 'delete' : 'list'),
            },
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Checkout
    server.tool(
      'gitCheckout',
      description: 'Switch branches or restore files',
      toolInputSchema: ToolInputSchema(
        properties: {
          'branch': {
            'type': 'string',
            'description': 'Branch name to checkout',
          },
          'create': {
            'type': 'boolean',
            'description': 'Create new branch',
            'default': false,
          },
          'files': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Files to restore',
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
      ),
      callback: ({args, extra}) async {
        final branch = args?['branch'] as String?;
        final create = args?['create'] as bool? ?? false;
        final files = (args?['files'] as List?)?.cast<String>();
        final path = args?['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          if (branch != null) {
            await git.checkout(branch, create: create);
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Checked out: $branch')],
            );
          } else if (files != null) {
            await git.checkoutFiles(files);
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Checked out files: ${files.join(", ")}'),
              ],
            );
          } else {
            return CallToolResult.fromContent(
              content: [
                TextContent(text: 'Error: Must specify branch or files'),
              ],
            );
          }
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitCheckout',
            context: {'create': create},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Stash
    server.tool(
      'gitStash',
      description: 'Stash or restore changes',
      toolInputSchema: ToolInputSchema(
        properties: {
          'action': {
            'type': 'string',
            'enum': ['save', 'pop', 'list', 'apply', 'drop', 'clear'],
            'description': 'Stash action',
            'default': 'save',
          },
          'message': {
            'type': 'string',
            'description': 'Stash message (for save)',
          },
          'index': {
            'type': 'integer',
            'description': 'Stash index (for apply/drop)',
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
      ),
      callback: ({args, extra}) async {
        final action = args?['action'] as String? ?? 'save';
        final message = args?['message'] as String?;
        final index = args?['index'] as int?;
        final path = args?['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          String result;
          switch (action) {
            case 'save':
              await git.stashPush(message: message);
              result = 'Stash saved';
              break;
            case 'pop':
              await git.stashPop(index: index);
              result = 'Stash popped';
              break;
            case 'list':
              result = await git.stashList();
              break;
            case 'apply':
              await git.stashApply(index: index);
              result = 'Stash applied';
              break;
            case 'drop':
              await git.stashDrop(index: index);
              result = 'Stash dropped';
              break;
            case 'clear':
              await git.stashClear();
              result = 'All stashes cleared';
              break;
            default:
              result = 'Unknown action: $action';
          }

          return CallToolResult.fromContent(
            content: [TextContent(text: result)],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitStash',
            context: {'action': action},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Worktree List
    server.tool(
      'gitWorktreeList',
      description: 'List all worktrees',
      toolInputSchema: ToolInputSchema(
        properties: {
          'path': {'type': 'string', 'description': 'Repository path'},
          'verbose': {
            'type': 'boolean',
            'description': 'Show detailed information',
            'default': false,
          },
        },
      ),
      callback: ({args, extra}) async {
        final path = args?['path'] as String? ?? Directory.current.path;
        final verbose = args?['verbose'] as bool? ?? false;

        try {
          final git = GitClient(workingDirectory: path);
          final worktrees = await git.worktreeList();

          if (verbose) {
            var output = 'Worktrees:\n';
            for (final wt in worktrees) {
              output += '\n  Path: ${wt.path}';
              output += '\n  Branch: ${wt.branch}';
              output += '\n  Commit: ${wt.commit}';
              if (wt.isLocked) {
                output += '\n  Locked: ${wt.lockReason ?? "yes"}';
              }
            }
            return CallToolResult.fromContent(
              content: [TextContent(text: output)],
            );
          }

          final result = worktrees
              .map((wt) => '${wt.path} ${wt.commit} [${wt.branch}]')
              .join('\n');
          return CallToolResult.fromContent(
            content: [TextContent(text: result)],
          );
        } catch (e, stackTrace) {
          await _reportError(e, stackTrace, 'gitWorktreeList');
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Worktree Add
    server.tool(
      'gitWorktreeAdd',
      description: 'Add a new worktree',
      toolInputSchema: ToolInputSchema(
        properties: {
          'path': {
            'type': 'string',
            'description': 'Path for the new worktree',
          },
          'branch': {
            'type': 'string',
            'description': 'Branch name for the worktree',
          },
          'createBranch': {
            'type': 'boolean',
            'description': 'Create a new branch',
            'default': false,
          },
          'basePath': {'type': 'string', 'description': 'Base repository path'},
        },
        required: ['path'],
      ),
      callback: ({args, extra}) async {
        final worktreePath = args!['path'] as String;
        final branch = args['branch'] as String?;
        final createBranch = args['createBranch'] as bool? ?? false;
        final basePath = args['basePath'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: basePath);
          await git.worktreeAdd(
            worktreePath,
            branch: branch,
            createBranch: createBranch,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Worktree added at: $worktreePath')],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitWorktreeAdd',
            context: {'create_branch': createBranch},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Worktree Remove
    server.tool(
      'gitWorktreeRemove',
      description: 'Remove a worktree',
      toolInputSchema: ToolInputSchema(
        properties: {
          'worktree': {
            'type': 'string',
            'description': 'Worktree path or name to remove',
          },
          'force': {
            'type': 'boolean',
            'description': 'Force removal even with uncommitted changes',
            'default': false,
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
        required: ['worktree'],
      ),
      callback: ({args, extra}) async {
        final worktree = args!['worktree'] as String;
        final force = args['force'] as bool? ?? false;
        final path = args['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          await git.worktreeRemove(worktree, force: force);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Worktree removed: $worktree')],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitWorktreeRemove',
            context: {'force': force},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Worktree Lock
    server.tool(
      'gitWorktreeLock',
      description: 'Lock a worktree',
      toolInputSchema: ToolInputSchema(
        properties: {
          'worktree': {
            'type': 'string',
            'description': 'Worktree path or name to lock',
          },
          'reason': {'type': 'string', 'description': 'Reason for locking'},
          'path': {'type': 'string', 'description': 'Repository path'},
        },
        required: ['worktree'],
      ),
      callback: ({args, extra}) async {
        final worktree = args!['worktree'] as String;
        final reason = args['reason'] as String?;
        final path = args['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          await git.worktreeLock(worktree, reason: reason);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Worktree locked: $worktree')],
          );
        } catch (e, stackTrace) {
          await _reportError(e, stackTrace, 'gitWorktreeLock');
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Worktree Unlock
    server.tool(
      'gitWorktreeUnlock',
      description: 'Unlock a worktree',
      toolInputSchema: ToolInputSchema(
        properties: {
          'worktree': {
            'type': 'string',
            'description': 'Worktree path or name to unlock',
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
        required: ['worktree'],
      ),
      callback: ({args, extra}) async {
        final worktree = args!['worktree'] as String;
        final path = args['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          await git.worktreeUnlock(worktree);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Worktree unlocked: $worktree')],
          );
        } catch (e, stackTrace) {
          await _reportError(e, stackTrace, 'gitWorktreeUnlock');
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Fetch
    server.tool(
      'gitFetch',
      description: 'Download objects and refs from remote',
      toolInputSchema: ToolInputSchema(
        properties: {
          'remote': {
            'type': 'string',
            'description': 'Remote name',
            'default': 'origin',
          },
          'all': {
            'type': 'boolean',
            'description': 'Fetch all remotes',
            'default': false,
          },
          'prune': {
            'type': 'boolean',
            'description': 'Prune remote branches',
            'default': false,
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
      ),
      callback: ({args, extra}) async {
        final remote = args?['remote'] as String? ?? 'origin';
        final all = args?['all'] as bool? ?? false;
        final prune = args?['prune'] as bool? ?? false;
        final path = args?['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          await git.fetch(remote: remote, all: all, prune: prune);
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Fetch completed')],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitFetch',
            context: {'remote': remote, 'all': all, 'prune': prune},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Pull
    server.tool(
      'gitPull',
      description: 'Fetch and merge changes from remote',
      toolInputSchema: ToolInputSchema(
        properties: {
          'remote': {
            'type': 'string',
            'description': 'Remote name',
            'default': 'origin',
          },
          'branch': {'type': 'string', 'description': 'Branch name'},
          'rebase': {
            'type': 'boolean',
            'description': 'Use rebase instead of merge',
            'default': false,
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
      ),
      callback: ({args, extra}) async {
        final remote = args?['remote'] as String? ?? 'origin';
        final branch = args?['branch'] as String?;
        final rebase = args?['rebase'] as bool? ?? false;
        final path = args?['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          final result = await git.pull(
            remote: remote,
            branch: branch,
            rebase: rebase,
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Pull completed: $result')],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitPull',
            context: {'remote': remote, 'rebase': rebase},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Merge
    server.tool(
      'gitMerge',
      description: 'Merge branches',
      toolInputSchema: ToolInputSchema(
        properties: {
          'branch': {'type': 'string', 'description': 'Branch to merge'},
          'message': {'type': 'string', 'description': 'Merge commit message'},
          'noCommit': {
            'type': 'boolean',
            'description': 'Perform merge but do not commit',
            'default': false,
          },
          'abort': {
            'type': 'boolean',
            'description': 'Abort current merge',
            'default': false,
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
      ),
      callback: ({args, extra}) async {
        final branch = args?['branch'] as String?;
        final message = args?['message'] as String?;
        final noCommit = args?['noCommit'] as bool? ?? false;
        final abort = args?['abort'] as bool? ?? false;
        final path = args?['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);

          if (abort) {
            await git.mergeAbort();
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Merge aborted')],
            );
          } else {
            if (branch == null) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(text: 'Error: Branch required for merge'),
                ],
              );
            }
            await git.merge(branch, message: message, noCommit: noCommit);
            return CallToolResult.fromContent(
              content: [TextContent(text: 'Merge completed')],
            );
          }
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitMerge',
            context: {'abort': abort, 'no_commit': noCommit},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );

    // Git Rebase
    server.tool(
      'gitRebase',
      description: 'Rebase current branch',
      toolInputSchema: ToolInputSchema(
        properties: {
          'onto': {'type': 'string', 'description': 'Branch to rebase onto'},
          'continue': {
            'type': 'boolean',
            'description': 'Continue rebase after resolving conflicts',
            'default': false,
          },
          'abort': {
            'type': 'boolean',
            'description': 'Abort current rebase',
            'default': false,
          },
          'skip': {
            'type': 'boolean',
            'description': 'Skip current patch',
            'default': false,
          },
          'path': {'type': 'string', 'description': 'Repository path'},
        },
      ),
      callback: ({args, extra}) async {
        final onto = args?['onto'] as String?;
        final continueRebase = args?['continue'] as bool? ?? false;
        final abort = args?['abort'] as bool? ?? false;
        final skip = args?['skip'] as bool? ?? false;
        final path = args?['path'] as String? ?? Directory.current.path;

        try {
          final git = GitClient(workingDirectory: path);
          String action;

          if (abort) {
            await git.rebaseAbort();
            action = 'aborted';
          } else if (continueRebase) {
            await git.rebaseContinue();
            action = 'continued';
          } else if (skip) {
            await git.rebaseSkip();
            action = 'skipped';
          } else {
            if (onto == null) {
              return CallToolResult.fromContent(
                content: [
                  TextContent(text: 'Error: Target branch required for rebase'),
                ],
              );
            }
            await git.rebase(onto);
            action = 'completed';
          }

          return CallToolResult.fromContent(
            content: [TextContent(text: 'Rebase $action')],
          );
        } catch (e, stackTrace) {
          await _reportError(
            e,
            stackTrace,
            'gitRebase',
            context: {'abort': abort, 'continue': continueRebase, 'skip': skip},
          );
          return CallToolResult.fromContent(
            content: [TextContent(text: 'Error: $e')],
          );
        }
      },
    );
  }

  @override
  Future<void> onStop() async {
    await _statusStream.close();
  }
}
