import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static const _currentChapterKey = 'currentChapter';
  static const _currentBookIdKey = 'currentBookId';
  static const _fontScaleKey = 'fontScale';
  static const _localeKey = 'locale';

  (int, int) get currentBookChapter {
    final bookId = _prefs.getInt(_currentBookIdKey) ?? 1;
    final chapter = _prefs.getInt(_currentChapterKey) ?? 1;
    return (bookId, chapter);
  }

  Future<void> setCurrentBookChapter(int bookId, int chapter) async {
    await _prefs.setInt(_currentBookIdKey, bookId);
    await _prefs.setInt(_currentChapterKey, chapter);
  }

  Future<void> setFontScale(double scale) async {
    await _prefs.setDouble(_fontScaleKey, scale);
  }

  double get fontScale => _prefs.getDouble(_fontScaleKey) ?? 1.0;

  Locale? get locale {
    final localeCode = _prefs.getString(_localeKey);
    if (localeCode == null) return null;
    return Locale(localeCode);
  }

  Future<void> setLocale(Locale locale) async {
    await _prefs.setString(_localeKey, locale.toString());
  }
}
