import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/local/settings_storage.dart';

part 'theme_provider.g.dart';

@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() {
    _loadFromStorage();
    return ThemeMode.system;
  }

  Future<void> _loadFromStorage() async {
    final storage = ref.read(settingsStorageProvider.notifier);
    final mode = await storage.getThemeMode();
    state = mode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final storage = ref.read(settingsStorageProvider.notifier);
    await storage.saveThemeMode(mode);
  }
}
