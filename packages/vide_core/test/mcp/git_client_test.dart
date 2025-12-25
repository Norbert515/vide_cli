import 'dart:io';
import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('GitClient', () {
    late Directory tempDir;
    late GitClient gitClient;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('git_client_test_');
      gitClient = GitClient(workingDirectory: tempDir.path);

      // Initialize git repo
      await Process.run('git', ['init'], workingDirectory: tempDir.path);
      await Process.run(
        'git',
        ['config', 'user.email', 'test@test.com'],
        workingDirectory: tempDir.path,
      );
      await Process.run(
        'git',
        ['config', 'user.name', 'Test User'],
        workingDirectory: tempDir.path,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('status', () {
      test('returns status for empty repo', () async {
        final status = await gitClient.status();

        expect(status.branch, isNotEmpty);
        expect(status.hasChanges, isFalse);
        expect(status.modifiedFiles, isEmpty);
        expect(status.untrackedFiles, isEmpty);
        expect(status.stagedFiles, isEmpty);
      });

      test('detects untracked files', () async {
        await File('${tempDir.path}/new_file.txt').writeAsString('content');

        final status = await gitClient.status();

        expect(status.hasChanges, isTrue);
        expect(status.untrackedFiles, contains('new_file.txt'));
      });

      test('detects modified files', () async {
        // Create initial commit
        final file = File('${tempDir.path}/file.txt');
        await file.writeAsString('initial');
        await gitClient.add(['.']);
        await gitClient.commit('Initial commit');

        // Modify file
        await file.writeAsString('modified');

        final status = await gitClient.status();

        expect(status.hasChanges, isTrue);
        expect(status.modifiedFiles, contains('file.txt'));
      });

      test('detects staged files', () async {
        await File('${tempDir.path}/staged.txt').writeAsString('content');
        await gitClient.add(['staged.txt']);

        final status = await gitClient.status();

        expect(status.hasChanges, isTrue);
        expect(status.stagedFiles, contains('staged.txt'));
      });
    });

    group('add', () {
      test('stages single file', () async {
        await File('${tempDir.path}/file.txt').writeAsString('content');

        await gitClient.add(['file.txt']);

        final status = await gitClient.status();
        expect(status.stagedFiles, contains('file.txt'));
      });

      test('stages multiple files', () async {
        await File('${tempDir.path}/file1.txt').writeAsString('content1');
        await File('${tempDir.path}/file2.txt').writeAsString('content2');

        await gitClient.add(['file1.txt', 'file2.txt']);

        final status = await gitClient.status();
        expect(status.stagedFiles, containsAll(['file1.txt', 'file2.txt']));
      });

      test('stages all with "."', () async {
        await File('${tempDir.path}/file1.txt').writeAsString('content1');
        await File('${tempDir.path}/file2.txt').writeAsString('content2');

        await gitClient.add(['.']);

        final status = await gitClient.status();
        expect(status.stagedFiles.length, 2);
      });
    });

    group('commit', () {
      test('creates commit', () async {
        await File('${tempDir.path}/file.txt').writeAsString('content');
        await gitClient.add(['.']);

        await gitClient.commit('Test commit');

        final commits = await gitClient.log(count: 1);
        expect(commits.length, 1);
        expect(commits.first.message, 'Test commit');
      });

      test('commit with all flag stages modified files', () async {
        // Create initial commit
        final file = File('${tempDir.path}/file.txt');
        await file.writeAsString('initial');
        await gitClient.add(['.']);
        await gitClient.commit('Initial');

        // Modify and commit with -a
        await file.writeAsString('modified');

        await gitClient.commit('Modified', all: true);

        final status = await gitClient.status();
        expect(status.hasChanges, isFalse);
      });
    });

    group('diff', () {
      test('shows working directory changes', () async {
        // Create initial commit
        final file = File('${tempDir.path}/file.txt');
        await file.writeAsString('initial content');
        await gitClient.add(['.']);
        await gitClient.commit('Initial');

        // Modify file
        await file.writeAsString('modified content');

        final diff = await gitClient.diff();

        expect(diff, contains('initial content'));
        expect(diff, contains('modified content'));
      });

      test('shows staged changes', () async {
        // Create initial commit
        final file = File('${tempDir.path}/file.txt');
        await file.writeAsString('initial');
        await gitClient.add(['.']);
        await gitClient.commit('Initial');

        // Modify and stage
        await file.writeAsString('modified');
        await gitClient.add(['file.txt']);

        final diff = await gitClient.diff(staged: true);

        expect(diff, contains('initial'));
        expect(diff, contains('modified'));
      });
    });

    group('log', () {
      test('returns commit history', () async {
        // Create commits
        for (var i = 1; i <= 3; i++) {
          await File('${tempDir.path}/file$i.txt').writeAsString('content$i');
          await gitClient.add(['.']);
          await gitClient.commit('Commit $i');
        }

        final commits = await gitClient.log(count: 3);

        expect(commits.length, 3);
        expect(commits[0].message, 'Commit 3');
        expect(commits[1].message, 'Commit 2');
        expect(commits[2].message, 'Commit 1');
      });

      test('respects count limit', () async {
        for (var i = 1; i <= 5; i++) {
          await File('${tempDir.path}/file$i.txt').writeAsString('content$i');
          await gitClient.add(['.']);
          await gitClient.commit('Commit $i');
        }

        final commits = await gitClient.log(count: 2);

        expect(commits.length, 2);
      });

      test('commits have required properties', () async {
        await File('${tempDir.path}/file.txt').writeAsString('content');
        await gitClient.add(['.']);
        await gitClient.commit('Test commit');

        final commits = await gitClient.log(count: 1);
        final commit = commits.first;

        expect(commit.hash, isNotEmpty);
        expect(commit.author, isNotEmpty);
        expect(commit.message, 'Test commit');
        expect(commit.date, isA<DateTime>());
      });
    });

    group('branches', () {
      test('lists current branch', () async {
        // Need at least one commit to have a branch
        await File('${tempDir.path}/file.txt').writeAsString('content');
        await gitClient.add(['.']);
        await gitClient.commit('Initial');

        final branches = await gitClient.branches();

        expect(branches.length, greaterThanOrEqualTo(1));
        expect(branches.where((b) => b.isCurrent).length, 1);
      });

      test('lists created branches', () async {
        await File('${tempDir.path}/file.txt').writeAsString('content');
        await gitClient.add(['.']);
        await gitClient.commit('Initial');

        await gitClient.createBranch('feature');

        final branches = await gitClient.branches();

        expect(branches.map((b) => b.name), contains('feature'));
      });
    });

    group('checkout', () {
      test('switches to existing branch', () async {
        await File('${tempDir.path}/file.txt').writeAsString('content');
        await gitClient.add(['.']);
        await gitClient.commit('Initial');
        await gitClient.createBranch('feature');

        await gitClient.checkout('feature');

        final current = await gitClient.currentBranch();
        expect(current, 'feature');
      });

      test('creates and switches to new branch', () async {
        await File('${tempDir.path}/file.txt').writeAsString('content');
        await gitClient.add(['.']);
        await gitClient.commit('Initial');

        await gitClient.checkout('new-feature', create: true);

        final current = await gitClient.currentBranch();
        expect(current, 'new-feature');
      });
    });

    group('currentBranch', () {
      test('returns current branch name', () async {
        await File('${tempDir.path}/file.txt').writeAsString('content');
        await gitClient.add(['.']);
        await gitClient.commit('Initial');

        final branch = await gitClient.currentBranch();

        expect(branch, isNotEmpty);
      });
    });

    group('stash operations', () {
      test('stash push and pop', () async {
        // Create initial commit
        final file = File('${tempDir.path}/file.txt');
        await file.writeAsString('initial');
        await gitClient.add(['.']);
        await gitClient.commit('Initial');

        // Make changes
        await file.writeAsString('modified');

        // Stash
        await gitClient.stashPush(message: 'WIP');

        var status = await gitClient.status();
        expect(status.hasChanges, isFalse);

        // Pop
        await gitClient.stashPop();

        status = await gitClient.status();
        expect(status.hasChanges, isTrue);
      });
    });

    group('error handling', () {
      test('throws GitException for invalid command', () async {
        expect(
          () => gitClient.checkout('nonexistent-branch'),
          throwsA(isA<GitException>()),
        );
      });

      test('GitException contains command info', () async {
        try {
          await gitClient.checkout('nonexistent');
          fail('Should have thrown');
        } on GitException catch (e) {
          expect(e.command, contains('checkout'));
          expect(e.exitCode, isNot(0));
        }
      });
    });
  });
}
