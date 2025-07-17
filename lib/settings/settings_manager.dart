import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

// enum Language {
//   english('en'),
//   spanish('es'),
//   system(null);

//   final String? code;
//   const Language(this.code);
// }

class SettingsManager extends ChangeNotifier {
  final _settings = getIt<UserSettings>();
  final appState = getIt<AppState>();
  final _glossService = getIt<GlossService>();

  static const defaultLocale = Locale('en');

  Locale get currentLocale => _settings.locale ?? defaultLocale;

  Future<void> setLocale(Locale selectedLocale) async {
    await _settings.setLocale(selectedLocale.languageCode);
    appState.init();
  }

  Future<bool> isLocaleDownloaded(Locale selectedLocale) async {
    return await _glossService.glossesExists(selectedLocale);
  }

  // Called from the UI when user agrees to download.
  Future<void> downloadGlosses(Locale locale) async {
    try {
      await _glossService.downloadGlosses(locale);
      // await _glossService.initDb(language.code!);
    } catch (e) {
      log('Gloss download failed for ${locale.languageCode}: $e');
      rethrow;
    }
  }
}
