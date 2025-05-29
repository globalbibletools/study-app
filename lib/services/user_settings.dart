import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static const _currentChapterKey = 'currentChapter';
  static const _currentBookIdKey = 'currentBookId';

  (int, int) get currentBookChapter {
    final bookId = _prefs.getInt(_currentBookIdKey) ?? 1;
    final chapter = _prefs.getInt(_currentChapterKey) ?? 1;
    return (bookId, chapter);
  }

  Future<void> setCurrentBookChapter(int bookId, int chapter) async {
    await _prefs.setInt(_currentBookIdKey, bookId);
    await _prefs.setInt(_currentChapterKey, chapter);
  }
}
