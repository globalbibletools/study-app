import 'package:gbt/services/settings/user_settings.dart';

/// Minimal [UserSettings] double for view-model tests: only the chapter
/// persistence API is needed, and it records writes so tests can assert on
/// dedupe behaviour.
class FakeUserSettings extends UserSettings {
  FakeUserSettings({int bookId = 1, int chapter = 1})
    : _bookId = bookId,
      _chapter = chapter;

  int _bookId;
  int _chapter;

  int saveCalls = 0;

  @override
  (int, int) get currentBookChapter => (_bookId, _chapter);

  @override
  Future<void> setCurrentBookChapter(int bookId, int chapter) async {
    _bookId = bookId;
    _chapter = chapter;
    saveCalls++;
  }
}
