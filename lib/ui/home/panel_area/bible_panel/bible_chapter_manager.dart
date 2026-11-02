import 'package:flutter/foundation.dart';
import 'package:scripture/scripture.dart'; // For UsfmLine
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/resources/resource_language.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

class BibleChapterManager {
  final _bibleService = getIt<BibleService>();
  final _settings = getIt<UserSettings>();
  final textNotifier = ValueNotifier<List<UsfmLine>>([]);

  ResourceLanguageTextDirection _textDirection =
      ResourceLanguageTextDirection.ltr;
  ResourceLanguageTextDirection get textDirection => _textDirection;

  bool get bibleChanged =>
      _settings.currentBible != _bibleService.currentBibleId;

  Future<void> loadChapterData(
    int bookId,
    int chapter, {
    void Function(String bibleId)? onDatabaseMissing,
  }) async {
    textNotifier.value = await _bibleService.getChapter(
      bookId,
      chapter,
      onDatabaseMissing: onDatabaseMissing,
    );
    _textDirection = _bibleService.currentTextDirection;
  }

  void dispose() {
    textNotifier.dispose();
  }
}
