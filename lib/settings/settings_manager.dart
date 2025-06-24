import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/services/database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

enum Language {
  english('en'),
  spanish('es'),
  system(null);

  final String? code;
  const Language(this.code);
}

class SettingsManager extends ChangeNotifier {
  final _settings = getIt<UserSettings>();
  final appState = getIt<AppState>();
  final _glossService = getIt<GlossService>();

  Language get currentLanguage {
    switch (_settings.locale?.languageCode) {
      case 'en':
        return Language.english;
      case 'es':
        return Language.spanish;
      default:
        return Language.system;
    }
  }

  Future<void> setLanguage(Language selectedLanguage) async {
    await _settings.setLocale(selectedLanguage.code);
    appState.init();
  }

  Future<bool> isLanguageDownloaded(Language selectedLanguage) async {
    return await _glossService.glossDbExists(selectedLanguage.code!);
  }

  // Called from the UI when user agrees to download.
  Future<void> downloadGlosses(Language language) async {
    try {
      await _glossService.downloadAndInstallGlossDb(language.code!);
      await _glossService.initDb(language.code!);
    } catch (e) {
      log('Gloss download failed for ${language.code!}: $e');
      rethrow;
    }
  }
}
