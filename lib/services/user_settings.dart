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
  static const _isHebrewSearchKey = 'isHebrewSearch';
  static const _useSystemKeyboardKey = 'useSystemKeyboard';

  (int, int) get currentBookChapter {
    final bookId = _prefs.getInt(_currentBookIdKey) ?? 1;
    final chapter = _prefs.getInt(_currentChapterKey) ?? 1;
    return (bookId, chapter);
  }

  Future<void> setCurrentBookChapter(int bookId, int chapter) async {
    await _prefs.setInt(_currentBookIdKey, bookId);
    await _prefs.setInt(_currentChapterKey, chapter);
  }

  double get fontScale => _prefs.getDouble(_fontScaleKey) ?? 1.0;

  Future<void> setFontScale(double scale) async {
    await _prefs.setDouble(_fontScaleKey, scale);
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
}
