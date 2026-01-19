import 'package:test/test.dart';
import 'package:vide_core/vide_core.dart';

void main() {
  group('SafeCommands - Basic read-only commands', () {
    test('allows safe file listing commands', () {
      expect(SafeCommands.isCommandSafe('ls'), isTrue);
      expect(SafeCommands.isCommandSafe('ls -la'), isTrue);
      expect(SafeCommands.isCommandSafe('pwd'), isTrue);
      expect(SafeCommands.isCommandSafe('tree'), isTrue);
      expect(SafeCommands.isCommandSafe('tree -L 2'), isTrue);
    });

    test('allows safe file reading commands', () {
      expect(SafeCommands.isCommandSafe('cat file.txt'), isTrue);
      expect(SafeCommands.isCommandSafe('head -n 10 file.txt'), isTrue);
      expect(SafeCommands.isCommandSafe('tail -f log.txt'), isTrue);
      expect(SafeCommands.isCommandSafe('less file.txt'), isTrue);
      expect(SafeCommands.isCommandSafe('more file.txt'), isTrue);
    });

    test('allows safe search commands', () {
      expect(SafeCommands.isCommandSafe('find . -name "*.dart"'), isTrue);
      expect(SafeCommands.isCommandSafe('grep "pattern" file.txt'), isTrue);
      expect(SafeCommands.isCommandSafe('rg "pattern"'), isTrue);
    });

    test('allows safe metadata commands', () {
      expect(SafeCommands.isCommandSafe('stat file.txt'), isTrue);
      expect(SafeCommands.isCommandSafe('file document.pdf'), isTrue);
      expect(SafeCommands.isCommandSafe('wc -l file.txt'), isTrue);
      expect(SafeCommands.isCommandSafe('du -sh directory'), isTrue);
      expect(SafeCommands.isCommandSafe('df -h'), isTrue);
    });

    test('allows safe environment commands', () {
      expect(SafeCommands.isCommandSafe('echo "hello"'), isTrue);
      expect(SafeCommands.isCommandSafe('env'), isTrue);
      expect(SafeCommands.isCommandSafe('printenv PATH'), isTrue);
      expect(SafeCommands.isCommandSafe('whoami'), isTrue);
      expect(SafeCommands.isCommandSafe('which dart'), isTrue);
    });

    test('allows safe data processing commands', () {
      expect(SafeCommands.isCommandSafe('sort file.txt'), isTrue);
      expect(SafeCommands.isCommandSafe('uniq data.txt'), isTrue);
      expect(SafeCommands.isCommandSafe('cut -d"," -f1 data.csv'), isTrue);
      expect(SafeCommands.isCommandSafe('jq ".name" data.json'), isTrue);
      expect(
        SafeCommands.isCommandSafe('awk \'{print \$1}\' file.txt'),
        isTrue,
      );
    });
  });

  group('SafeCommands - Git commands', () {
    test('allows safe git read commands', () {
      expect(SafeCommands.isCommandSafe('git status'), isTrue);
      expect(SafeCommands.isCommandSafe('git log'), isTrue);
      expect(SafeCommands.isCommandSafe('git log --oneline'), isTrue);
      expect(SafeCommands.isCommandSafe('git diff'), isTrue);
      expect(SafeCommands.isCommandSafe('git show HEAD'), isTrue);
      expect(SafeCommands.isCommandSafe('git branch'), isTrue);
      expect(SafeCommands.isCommandSafe('git remote -v'), isTrue);
      expect(SafeCommands.isCommandSafe('git blame file.txt'), isTrue);
    });

    test('blocks unsafe git write commands', () {
      expect(SafeCommands.isCommandSafe('git commit -m "message"'), isFalse);
      expect(SafeCommands.isCommandSafe('git push'), isFalse);
      expect(SafeCommands.isCommandSafe('git pull'), isFalse);
      expect(SafeCommands.isCommandSafe('git checkout branch'), isFalse);
      expect(SafeCommands.isCommandSafe('git merge branch'), isFalse);
      expect(SafeCommands.isCommandSafe('git rebase main'), isFalse);
      expect(SafeCommands.isCommandSafe('git reset --hard'), isFalse);
    });
  });

  group('SafeCommands - Package manager commands', () {
    test('allows safe npm read commands', () {
      expect(SafeCommands.isCommandSafe('npm list'), isTrue);
      expect(SafeCommands.isCommandSafe('npm ls'), isTrue);
      expect(SafeCommands.isCommandSafe('npm view package'), isTrue);
      expect(SafeCommands.isCommandSafe('npm outdated'), isTrue);
    });

    test('blocks unsafe npm write commands', () {
      expect(SafeCommands.isCommandSafe('npm install'), isFalse);
      expect(SafeCommands.isCommandSafe('npm install package'), isFalse);
      expect(SafeCommands.isCommandSafe('npm uninstall package'), isFalse);
      expect(SafeCommands.isCommandSafe('npm update'), isFalse);
    });

    test('allows safe dart read commands', () {
      expect(SafeCommands.isCommandSafe('dart analyze'), isTrue);
      expect(SafeCommands.isCommandSafe('dart doc'), isTrue);
      expect(SafeCommands.isCommandSafe('dart pub deps'), isTrue);
    });

    test('blocks unsafe dart commands', () {
      expect(SafeCommands.isCommandSafe('dart run main.dart'), isFalse);
      expect(SafeCommands.isCommandSafe('dart compile exe main.dart'), isFalse);
    });

    test('allows safe pip read commands', () {
      expect(SafeCommands.isCommandSafe('pip list'), isTrue);
      expect(SafeCommands.isCommandSafe('pip show package'), isTrue);
    });

    test('blocks unsafe pip write commands', () {
      expect(SafeCommands.isCommandSafe('pip install package'), isFalse);
      expect(SafeCommands.isCommandSafe('pip uninstall package'), isFalse);
    });
  });

  group('SafeCommands - Dangerous commands', () {
    test('blocks destructive commands', () {
      expect(SafeCommands.isCommandSafe('rm file.txt'), isFalse);
      expect(SafeCommands.isCommandSafe('rm -rf directory'), isFalse);
      expect(SafeCommands.isCommandSafe('rmdir directory'), isFalse);
      expect(SafeCommands.isCommandSafe('dd if=/dev/zero of=file'), isFalse);
    });

    test('blocks privilege escalation', () {
      expect(SafeCommands.isCommandSafe('sudo ls'), isFalse);
      expect(SafeCommands.isCommandSafe('su -'), isFalse);
    });

    test('blocks network commands', () {
      expect(SafeCommands.isCommandSafe('curl https://example.com'), isFalse);
      expect(SafeCommands.isCommandSafe('wget https://example.com'), isFalse);
      expect(SafeCommands.isCommandSafe('ssh user@host'), isFalse);
      expect(SafeCommands.isCommandSafe('scp file user@host:/path'), isFalse);
    });

    test('blocks process control commands', () {
      expect(SafeCommands.isCommandSafe('kill 1234'), isFalse);
      expect(SafeCommands.isCommandSafe('killall process'), isFalse);
      expect(SafeCommands.isCommandSafe('pkill process'), isFalse);
    });

    test('blocks system modification commands', () {
      expect(SafeCommands.isCommandSafe('chmod 777 file'), isFalse);
      expect(SafeCommands.isCommandSafe('chown user:group file'), isFalse);
      expect(SafeCommands.isCommandSafe('mount /dev/sda1 /mnt'), isFalse);
    });
  });

  group('SafeCommands - Dangerous flags', () {
    test('blocks output redirection', () {
      expect(SafeCommands.isCommandSafe('cat file.txt > output.txt'), isFalse);
      expect(SafeCommands.isCommandSafe('echo "text" >> file.txt'), isFalse);
    });

    test('allows stderr redirection', () {
      expect(SafeCommands.isCommandSafe('ls 2> /dev/null'), isTrue);
      expect(SafeCommands.isCommandSafe('git status 2>&1'), isTrue);
    });

    test('blocks dangerous find flags', () {
      expect(
        SafeCommands.isCommandSafe('find . -name "*.tmp" -delete'),
        isFalse,
      );
    });

    test('blocks in-place sed editing', () {
      expect(
        SafeCommands.isCommandSafe('sed -i "s/old/new/" file.txt'),
        isFalse,
      );
    });

    test('allows safe sed without in-place editing', () {
      expect(SafeCommands.isCommandSafe('sed "s/old/new/" file.txt'), isTrue);
    });
  });

  group('SafeCommands - Process inspection', () {
    test('allows process inspection commands', () {
      expect(SafeCommands.isCommandSafe('ps aux'), isTrue);
      expect(SafeCommands.isCommandSafe('ps -ef'), isTrue);
      expect(SafeCommands.isCommandSafe('top'), isTrue);
      expect(SafeCommands.isCommandSafe('htop'), isTrue);
    });
  });

  group('SafeCommands - Edge cases', () {
    test('handles empty and whitespace commands', () {
      expect(SafeCommands.isCommandSafe(''), isFalse);
      expect(SafeCommands.isCommandSafe('   '), isFalse);
    });

    test('handles commands with multiple spaces', () {
      expect(SafeCommands.isCommandSafe('ls   -la   /path'), isTrue);
      expect(SafeCommands.isCommandSafe('git    status'), isTrue);
    });
  });
}
