import 'package:flutter/material.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/services/bible/bible_service.dart';
import 'package:studyapp/services/download/cancel_token.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/settings/user_settings.dart';

class HebrewGreekChapterManager {
  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();
  final _glossService = getIt<GlossService>();
  final _bibleService = getIt<BibleService>();
  final _settings = getIt<UserSettings>();
  final _rsmanager = getIt<ReadingSessionManager>();

  final textNotifier = ValueNotifier<List<HebrewGreekWord>>([]);
  final verseCheckboxNotifier = VerseCheckboxNotifier();

  Future<void> loadChapterData(int bookId, int chapter) async {
    textNotifier.value = [];
    textNotifier.value = await _hebrewGreekDb.getChapter(bookId, chapter);
  }

  Future<void> loadReadVerses(int bookId, int chapter) async {
    verseCheckboxNotifier.clear();
    verseCheckboxNotifier.setVersesRead(
      await _rsmanager.getVersesReadForChapter(bookId, chapter),
    );
  }

  Future<void> markVerseAsRead(int bookId, int chapter, int verse) async {
    await _rsmanager.markVerseAsRead(bookId, chapter, verse);
    verseCheckboxNotifier.setVersesRead(
      await _rsmanager.getVersesReadForChapter(bookId, chapter),
    );
  }

  Future<void> resetVerseProgress(int bookId, int chapter, int verse) async {
    await _rsmanager.resetReadingCountForVerse(bookId, chapter, verse);
    final versesRead = await _rsmanager.getVersesReadForChapter(
      bookId,
      chapter,
    );
    verseCheckboxNotifier.setVersesRead(versesRead);
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
  Future<void> downloadResources(
    Locale locale, {
    required ValueNotifier<double> progressNotifier,
    required CancelToken cancelToken,
  }) async {
    // Reuse the exact same logic as SettingsManager
    // 1. Determine tasks
    final needGloss = !await _glossService.glossesExists(locale);
    final needBible = !await _bibleService.bibleExists(locale);

    int tasksToRun = (needGloss ? 1 : 0) + (needBible ? 1 : 0);
    int tasksCompleted = 0;

    void updateProgress(double fileProgress) {
      if (tasksToRun == 0) {
        progressNotifier.value = 1.0;
        return;
      }
      final overall =
          (tasksCompleted / tasksToRun) + (fileProgress / tasksToRun);
      progressNotifier.value = overall;
    }

    // 2. Glosses
    if (needGloss) {
      if (cancelToken.isCancelled) return;
      await _glossService.downloadGlosses(
        locale,
        cancelToken: cancelToken,
        onProgress: updateProgress,
      );
      tasksCompleted++;
    }

    // 3. Bible
    if (needBible) {
      if (cancelToken.isCancelled) return;
      updateProgress(0.0);
      await _bibleService.downloadBible(
        locale,
        cancelToken: cancelToken,
        onProgress: updateProgress,
      );
      tasksCompleted++;
    }

    progressNotifier.value = 1.0;
  }

  // Called from the UI when user wants to use English instead of downloading.
  Future<void> setLanguageToEnglish(Locale originalLocale) async {
    await _settings.setLocale('en');
    getIt<AppState>().init();
  }

  String getVerseText(int verse) {
    final words = textNotifier.value;
    final verseWords = words
        .where((w) => (w.id ~/ 100) % 1000 == verse)
        .toList();

    if (verseWords.isEmpty) return '';

    final buffer = StringBuffer();
    // Maqaph (Hebrew hyphen) indicates words should be connected without space.
    const maqaph = '־';

    for (int i = 0; i < verseWords.length; i++) {
      final text = verseWords[i].text;
      buffer.write(text);

      // Add space if it's not the last word and doesn't end with a maqaph
      if (i < verseWords.length - 1 && !text.endsWith(maqaph)) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  void dispose() {
    textNotifier.dispose();
    verseCheckboxNotifier.dispose();
  }
}

class VerseCheckboxNotifier extends ChangeNotifier {
  Map<int, int> _value = {};

  Map<int, int> get value => Map.unmodifiable(_value);

  void setVersesRead(Map<int, int> versesRead) {
    _value = versesRead;
    notifyListeners();
  }

  void clear() {
    _value = {};
    notifyListeners();
  }
}
