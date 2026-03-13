import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

enum VerseLayout { paragraph, versePerLine }

class UserSettings {
  late SharedPreferences _prefs;
  late Map<int, int> progress = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await getBooksProgress();
  }

  static const _themeModeKey = 'themeMode';
  static const _currentChapterKey = 'currentChapter';
  static const _currentBookIdKey = 'currentBookId';
  static const _hebrewFontScaleKey = 'hebrewFontScale';
  static const _greekFontScaleKey = 'greekFontScale';
  static const _bibleFontScaleKey = 'bibleFontScale';
  static const _wordDetailsFontScaleKey = 'wordDetailsFontScale';
  static const _localeKey = 'locale';
  static const _isHebrewSearchKey = 'isHebrewSearch';
  static const _useSystemKeyboardKey = 'useSystemKeyboard';
  static const _currentBible = 'currentBible';
  static const _booksProgress = 'booksProgress';
  static const _verseLayout = "verseLayout";

  String? get themeMode {
    return _prefs.getString(_themeModeKey);
  }

  Future<void> setThemeMode(String? value) async {
    if (value == null) {
      await _prefs.remove(_themeModeKey);
      return;
    }
    await _prefs.setString(_themeModeKey, value);
  }

  bool get hasSetLocale => _prefs.containsKey(_localeKey);

  (int, int) get currentBookChapter {
    final bookId = _prefs.getInt(_currentBookIdKey) ?? 1;
    final chapter = _prefs.getInt(_currentChapterKey) ?? 1;
    return (bookId, chapter);
  }

  Future<void> setCurrentBookChapter(int bookId, int chapter) async {
    await _prefs.setInt(_currentBookIdKey, bookId);
    await _prefs.setInt(_currentChapterKey, chapter);
    progress[bookId] = chapter;
    await _prefs.setString(_booksProgress, mapToString(progress));
  }

  double get baseFontSize => 20.0;

  double get hebrewFontScale => _prefs.getDouble(_hebrewFontScaleKey) ?? 1.0;

  Future<void> setHebrewFontScale(double scale) async {
    await _prefs.setDouble(_hebrewFontScaleKey, scale);
  }

  double get greekFontScale => _prefs.getDouble(_greekFontScaleKey) ?? 1.0;

  Future<void> setGreekFontScale(double scale) async {
    await _prefs.setDouble(_greekFontScaleKey, scale);
  }

  double get bibleFontScale => _prefs.getDouble(_bibleFontScaleKey) ?? 1.0;

  Future<void> setBibleFontScale(double scale) async {
    await _prefs.setDouble(_bibleFontScaleKey, scale);
  }

  double get wordDetailsFontScale =>
      _prefs.getDouble(_wordDetailsFontScaleKey) ?? 1.0;

  Future<void> setWordDetailsFontScale(double scale) async {
    await _prefs.setDouble(_wordDetailsFontScaleKey, scale);
  }

  Locale get locale {
    final localeCode = _prefs.getString(_localeKey) ?? 'en';
    return Locale(localeCode);
  }

  Future<void> setLocale(String? localeCode) async {
    if (localeCode == null) {
      await _prefs.remove(_localeKey);
    } else {
      await _prefs.setString(_localeKey, localeCode);
    }
  }

  bool get isHebrewSearch {
    return _prefs.getBool(_isHebrewSearchKey) ?? true;
  }

  Future<void> setIsHebrewSearch(bool value) async {
    await _prefs.setBool(_isHebrewSearchKey, value);
  }

  bool get shouldUseSystemKeyboard {
    return _prefs.getBool(_useSystemKeyboardKey) ?? false;
  }

  Future<void> setUseSystemKeyboard(bool value) async {
    await _prefs.setBool(_useSystemKeyboardKey, value);
  }

  String? get currentBible {
    return _prefs.getString(_currentBible);
  }

  VerseLayout get verseLayout {
    return VerseLayout.values[_prefs.getInt(_verseLayout) ?? 0];
  }

  Future<void> setVerseLayout(VerseLayout value) async {
    await _prefs.setInt(_verseLayout, value.index);
  }

  /// Set language and version of the currently selected Bible
  ///
  /// Example: eng_bsb (English - Berean Standard Bible)
  /// null means the user has not downloaded a Bible or non is selected.
  Future<void> setCurrentBible(String? bibleCode) async {
    if (bibleCode == null) {
      _prefs.remove(_currentBible);
    } else {
      await _prefs.setString((_currentBible), bibleCode);
    }
  }

  Future<void> getBooksProgress() async {
    String? progressString = _prefs.getString(_booksProgress);
    if (progressString != null) {
      // map format : bookId1:chapterId1,bookId2:chapterId2
      progress = parseStringToMap(progressString);
    }
  }

  int getCurrentProgressForBook(int bookId) {
    return progress[bookId] ?? 0;
  }

  Map<int, int> parseStringToMap(String input) {
    final map = <int, int>{};

    if (input.isEmpty) return map;

    // Split by comma for each pair
    final pairs = input.split(',');

    for (var pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = int.tryParse(keyValue[0].trim());
        final value = int.tryParse(keyValue[1].trim());
        if (key != null && value != null) {
          map[key] = value;
        }
      }
    }

    return map;
  }

  String mapToString(Map<int, int> map) {
    return map.entries.map((e) => '${e.key}:${e.value}').join(',');
  }
}
