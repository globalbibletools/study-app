import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/l10n/app_languages.dart';
import 'package:studyapp/services/bible/bible_service.dart';
import 'package:studyapp/services/download/cancel_token.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/settings/user_settings.dart';

class SettingsManager extends ChangeNotifier {
  final _settings = getIt<UserSettings>();
  final appState = getIt<AppState>();
  final _glossService = getIt<GlossService>();
  final _bibleService = getIt<BibleService>();

  ThemeMode get currentThemeMode => appState.themeMode;

  void setThemeMode(ThemeMode mode) {
    appState.updateThemeMode(mode);
    notifyListeners();
  }

  Locale get currentLocale => _settings.locale;

  String get currentLanguageName {
    final config = AppLanguages.getConfig(currentLocale.languageCode);
    return config.nativeName;
  }

  Future<void> setLocale(Locale selectedLocale) async {
    await _settings.setLocale(selectedLocale.languageCode);
    appState.init();
    notifyListeners();
  }

  /// Checks if BOTH Bible and Glosses are downloaded for this locale.
  Future<bool> areResourcesDownloaded(Locale locale) async {
    if (locale.languageCode == 'en') return true;

    final bibleExists = await _bibleService.bibleExists(locale);
    final glossExists = await _glossService.glossesExists(locale);

    return bibleExists && glossExists;
  }

  /// Downloads BOTH Bible and Glosses with Progress Reporting
  Future<void> downloadResources(
    Locale locale, {
    required ValueNotifier<double> progressNotifier, // UI Notifier
    required CancelToken cancelToken, // Token to stop
  }) async {
    try {
      // 1. Determine what needs downloading
      final needGloss = !await _glossService.glossesExists(locale);
      final needBible = !await _bibleService.bibleExists(locale);

      int tasksToRun = (needGloss ? 1 : 0) + (needBible ? 1 : 0);
      int tasksCompleted = 0;

      // Helper to update progress based on current task index
      void updateProgress(double fileProgress) {
        if (tasksToRun == 0) {
          progressNotifier.value = 1.0;
          return;
        }
        // Example: If 2 tasks. Task 1 (0.0 -> 0.5). Task 2 (0.5 -> 1.0)
        final overall =
            (tasksCompleted / tasksToRun) + (fileProgress / tasksToRun);
        progressNotifier.value = overall;
      }

      // 2. Download Glosses
      if (needGloss) {
        if (cancelToken.isCancelled) return;

        await _glossService.downloadGlosses(
          locale,
          cancelToken: cancelToken,
          onProgress: updateProgress,
        );
        tasksCompleted++;
      }

      // 3. Download Bible
      if (needBible) {
        if (cancelToken.isCancelled) return;

        // Reset file progress for the next calculation
        updateProgress(0.0);

        await _bibleService.downloadBible(
          locale,
          cancelToken: cancelToken,
          onProgress: updateProgress,
        );
        tasksCompleted++;
      }

      // Ensure we hit 100% at the end
      progressNotifier.value = 1.0;
    } catch (e) {
      log('Resource download failed for ${locale.languageCode}: $e');
      rethrow;
    }
  }

  // --- Font Sizes ---

  double get minFontSize => 10;
  double get maxFontSize => 60;
  int get fontSizeDivisions => 50;

  // Hebrew
  double get hebrewTextSize =>
      (_settings.baseFontSize * _settings.hebrewFontScale).roundToDouble();

  Future<void> setHebrewTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setHebrewFontScale(scale);
    notifyListeners();
  }

  // Greek
  double get greekTextSize =>
      (_settings.baseFontSize * _settings.greekFontScale).roundToDouble();

  Future<void> setGreekTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setGreekFontScale(scale);
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
