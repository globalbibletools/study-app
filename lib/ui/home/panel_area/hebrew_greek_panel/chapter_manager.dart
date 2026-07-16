import 'package:flutter/material.dart';
import 'package:gbt/common/word.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

class HebrewGreekChapterManager {
  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();
  final _glossService = getIt<GlossService>();
  final _settings = getIt<UserSettings>();
  final _rsmanager = getIt<ReadingSessionManager>();

  final textNotifier = _SafeValueNotifier<List<HebrewGreekWord>>([]);
  final verseCheckboxNotifier = VerseCheckboxNotifier();
  bool _disposed = false;
  int _chapterLoadToken = 0;
  int _readVersesLoadToken = 0;

  Future<void> loadChapterData(int bookId, int chapter) async {
    final token = ++_chapterLoadToken;
    if (_disposed) return;
    textNotifier.value = [];
    final words = await _hebrewGreekDb.getChapter(bookId, chapter);
    if (_disposed || token != _chapterLoadToken) return;
    textNotifier.value = words;
  }

  Future<void> loadReadVerses(int bookId, int chapter) async {
    final token = ++_readVersesLoadToken;
    if (_disposed) return;
    verseCheckboxNotifier.clear();
    final versesRead = await _rsmanager.getVersesReadForChapter(
      bookId,
      chapter,
    );
    if (_disposed || token != _readVersesLoadToken) return;
    verseCheckboxNotifier.setVersesRead(versesRead);
  }

  Future<void> markVerseAsRead(int bookId, int chapter, int verse) async {
    if (_disposed) return;
    await _rsmanager.markVerseAsRead(bookId, chapter, verse);
    if (_disposed) return;
    final versesRead = await _rsmanager.getVersesReadForChapter(
      bookId,
      chapter,
    );
    if (_disposed) return;
    verseCheckboxNotifier.setVersesRead(versesRead, changedVerse: verse);
  }

  Future<void> resetVerseProgress(int bookId, int chapter, int verse) async {
    if (_disposed) return;
    await _rsmanager.resetReadingCountForVerse(bookId, chapter, verse);
    if (_disposed) return;
    final versesRead = await _rsmanager.getVersesReadForChapter(
      bookId,
      chapter,
    );
    if (_disposed) return;
    verseCheckboxNotifier.setVersesRead(versesRead, changedVerse: verse);
  }

  bool isRtl(int bookId) {
    const malachi = 39;
    return bookId <= malachi;
  }

  Future<String?> getPopupTextForId(
    int wordId,
    void Function(String)? onGlossDownloadNeeded,
  ) async {
    return _glossService.glossForId(
      wordId: wordId,
      onDatabaseMissing: onGlossDownloadNeeded,
    );
  }

  // Called from the UI when user wants to use English instead of downloading.
  Future<void> setGlossToEnglish() async {
    await _settings.setGlossLang('eng');
  }

  String getVerseText(int verse) {
    if (_disposed) return '';
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
    _disposed = true;
    _chapterLoadToken++;
    _readVersesLoadToken++;
    textNotifier.dispose();
    verseCheckboxNotifier.dispose();
  }
}

class VerseCheckboxNotifier extends ChangeNotifier {
  Map<int, int> _value = const {};
  int? _changedVerse;
  bool _resetAll = true;
  int _revision = 0;
  bool _disposed = false;

  Map<int, int> get value => _value;
  int? get changedVerse => _changedVerse;
  bool get resetAll => _resetAll;
  int get revision => _revision;

  void setVersesRead(Map<int, int> versesRead, {int? changedVerse}) {
    if (_disposed) return;
    _value = Map<int, int>.unmodifiable(versesRead);
    _changedVerse = changedVerse;
    _resetAll = changedVerse == null;
    _revision++;
    notifyListeners();
  }

  void clear() {
    if (_disposed) return;
    _value = const {};
    _changedVerse = null;
    _resetAll = true;
    _revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _SafeValueNotifier<T> extends ValueNotifier<T> {
  _SafeValueNotifier(super.value);

  bool _disposed = false;

  @override
  set value(T newValue) {
    if (_disposed) return;
    super.value = newValue;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
