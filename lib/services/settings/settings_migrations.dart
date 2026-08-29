/*
SETTINGS MIGRATIONS

Settings migrations allow us to gracefully change the schema of user settings
with minimal disruptions to the user.

To add a new migration:
1. Add a new function named migrateV* in descending order at the end of this file.
2. Add the function to the end of the _settingsMigration list.

When the app is opened, it will run any new migrations that it finds.
It is important that we do not delete any migrations
since we don't know how many versions the user might have skipped.
*/

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
    migrateV1,
];

Future<void> migrateV1(SharedPreferences settings) async {
    final locale = settings.getString('locale');

    switch (locale) {
        case 'es': {
            await settings.setString("currentBible", "spa_blm");
            await settings.setString("glossLang", "spa");
        }
        case 'fr': {
            await settings.setString("currentBible", "fra_lsg");
            await settings.setString("glossLang", "fra");
        }
        case 'pt': {
            await settings.setString("currentBible", "por_blj");
            await settings.setString("glossLang", "por");
        }
        case 'ar': {
            await settings.setString("currentBible", "arb_vdv");
            await settings.setString("glossLang", "are");
        }
        default: {
            await settings.setString("currentBible", "eng_bsb");
            await settings.setString("glossLang", "eng");
        }
    }
}

