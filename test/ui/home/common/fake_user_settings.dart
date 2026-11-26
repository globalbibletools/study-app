import 'package:gbt/common/reference.dart';
import 'package:gbt/services/settings/user_settings.dart';

/// Minimal [UserSettings] double for view-model tests: only the reading
/// position persistence API is needed, and it records writes so tests can
/// assert on dedupe behaviour.
class FakeUserSettings extends UserSettings {
  FakeUserSettings({int bookId = 1, int chapter = 1, int verse = 1})
    : _reference = Reference(bookId: bookId, chapter: chapter, verse: verse);

  Reference _reference;

  int saveCalls = 0;

  @override
  Reference get currentReference => _reference;

  @override
  Future<void> setCurrentReference(Reference ref) async {
    _reference = ref;
    saveCalls++;
  }
}
