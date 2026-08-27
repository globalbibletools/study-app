import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

final expectedVersion = _settingsMigrations.length;
const _settingsVersionKey = 'settingsVersion';

Future<void> migrateSettings(SharedPreferences settings) async {
  final currentVersion = settings.getInt(_settingsVersionKey) ?? 0;

  for (var i = currentVersion; i < expectedVersion; i++) {
    try {
        await _settingsMigrations[i](settings);
        log("Migrated settings to version ${currentVersion + 1}");
    } catch (error) {
        log("Failed to migrate settings to version ${currentVersion + 1}: $error");
    }

    await settings.setInt(_settingsVersionKey, i + 1);
  }
}

const List<Future<void> Function(SharedPreferences)> _settingsMigrations = [
];
