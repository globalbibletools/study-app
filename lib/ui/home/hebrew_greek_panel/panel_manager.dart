import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class HebrewGreekPanelManager {
  final _settings = getIt<UserSettings>();
  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();
  final _glossService = getIt<GlossService>();
  // final textNotifier = ValueNotifier<List<HebrewGreekWord>>([]);
  late final fontScaleNotifier = ValueNotifier<double>(_settings.fontScale);

  double get baseFontSize => _settings.baseFontSize;

  Future<void> saveFontScale(double scale) async {
    await _settings.setFontScale(scale);
  }

  // Future<void> loadChapter(int bookId, int chapter) async {
  //   if (textNotifier.value.isNotEmpty) return;
  //   textNotifier.value = await _hebrewGreekDb.getChapter(bookId, chapter);
  // }

  Future<List<HebrewGreekWord>> getChapterData(int bookId, int chapter) async {
    return _hebrewGreekDb.getChapter(bookId, chapter);
  }

  bool isRtl(int bookId) {
    const malachi = 39;
    return bookId <= malachi;
  }

  Future<String?> getPopupTextForId(
    Locale uiLocale,
    int wordId,
    void Function(Locale)? onGlossDownloadNeeded,
  ) async {
    return _glossService.glossForId(
      locale: uiLocale,
      wordId: wordId,
      onDatabaseMissing: onGlossDownloadNeeded,
    );
  }

  // Called from the UI when user agrees to download.
  Future<void> downloadGlosses(Locale locale) async {
    await _glossService.downloadGlosses(locale);
  }

  // Called from the UI when user wants to use English instead of downloading.
  Future<void> setLanguageToEnglish(Locale originalLocale) async {
    await _settings.setLocale('en');
    getIt<AppState>().init();
  }

  void dispose() {
    // textNotifier.dispose();
    fontScaleNotifier.dispose();
  }
}
