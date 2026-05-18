import 'dart:async';
import 'dart:io';

import 'package:vide_core/vide_core.dart' show VideConfigManager;

enum SoundType { taskComplete, attentionNeeded }

class SoundService {
  static DateTime? _lastPlayedAt;
  static const _debounceDuration = Duration(seconds: 2);

  static void play(SoundType type, VideConfigManager configManager) {
    final settings = configManager.readGlobalSettings();
    if (!settings.soundNotificationsEnabled) return;

    final now = DateTime.now();
    if (_lastPlayedAt != null &&
        now.difference(_lastPlayedAt!) < _debounceDuration) {
      return;
    }
    _lastPlayedAt = now;

    final customPath = switch (type) {
      SoundType.taskComplete => settings.customTaskCompleteSound,
      SoundType.attentionNeeded => settings.customAttentionNeededSound,
    };

    if (customPath != null) {
      _playCustom(customPath);
    } else {
      _playSystemSound(type);
    }
  }

  /// Play a sound directly, bypassing the setting check and debounce.
  static void playDirect(SoundType type, {String? customPath}) {
    if (customPath != null) {
      _playCustom(customPath);
    } else {
      _playSystemSound(type);
    }
  }

  static void _playCustom(String path) {
    if (Platform.isMacOS) {
      unawaited(Process.run('afplay', [path]));
    } else if (Platform.isLinux) {
      unawaited(Process.run('ffplay', ['-nodisp', '-autoexit', '-loglevel', 'quiet', path]));
    } else if (Platform.isWindows) {
      unawaited(Process.run(
        'powershell',
        ['-c', '(New-Object Media.SoundPlayer "$path").PlaySync()'],
      ));
    } else {
      stdout.write('\x07');
    }
  }

  static void _playSystemSound(SoundType type) {
    if (Platform.isMacOS) {
      _playMacOS(type);
    } else if (Platform.isLinux) {
      _playLinux(type);
    } else if (Platform.isWindows) {
      _playWindows();
    } else {
      stdout.write('\x07');
    }
  }

  static void _playMacOS(SoundType type) {
    final sound = switch (type) {
      SoundType.taskComplete => 'Glass',
      SoundType.attentionNeeded => 'Ping',
    };
    unawaited(
      Process.run('afplay', ['/System/Library/Sounds/$sound.aiff']),
    );
  }

  static void _playLinux(SoundType type) {
    final sound = switch (type) {
      SoundType.taskComplete => 'complete.oga',
      SoundType.attentionNeeded => 'dialog-warning.oga',
    };
    unawaited(
      Process.run(
        'paplay',
        ['/usr/share/sounds/freedesktop/stereo/$sound'],
      ),
    );
  }

  static void _playWindows() {
    unawaited(
      Process.run(
        'powershell',
        ['-c', '[System.Media.SystemSounds]::Asterisk.Play()'],
      ),
    );
  }
}
