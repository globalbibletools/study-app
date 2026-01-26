import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class SettingsManager extends ChangeNotifier {
  final _settings = getIt<UserSettings>();
  final appState = getIt<AppState>();
  final _glossService = getIt<GlossService>();

  ThemeMode get currentThemeMode => appState.themeMode;

  void setThemeMode(ThemeMode mode) {
    appState.updateThemeMode(mode);
    notifyListeners();
  }

  Locale get currentLocale => _settings.locale;

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
    } catch (e) {
      log('Gloss download failed for ${locale.languageCode}: $e');
      rethrow;
    }
  }

  // --- Font Sizes ---

  double get minFontSize => 10;
  double get maxFontSize => 60;
  int get fontSizeDivisions => 50;

  // Hebrew/Greek
  double get hebrewTextSize =>
      (_settings.baseFontSize * _settings.hebrewGreekFontScale).roundToDouble();

  Future<void> setHebrewTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setHebrewGreekFontScale(scale);
    notifyListeners();
  }

  // Bible (English/Translation)
  double get bibleTextSize =>
      (_settings.baseFontSize * _settings.bibleFontScale).roundToDouble();

  Future<void> setBibleTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setBibleFontScale(scale);
    notifyListeners();
  }

  // Word Details (Lexicon/Popup)
  double get lexiconTextSize =>
      (_settings.baseFontSize * _settings.wordDetailsFontScale).roundToDouble();

  Future<void> setLexiconTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setWordDetailsFontScale(scale);
    notifyListeners();
  }
}
