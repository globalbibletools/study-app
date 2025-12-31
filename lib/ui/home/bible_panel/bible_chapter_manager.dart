import 'package:flutter/foundation.dart';
import 'package:scripture/scripture.dart'; // For UsfmLine
import 'package:studyapp/services/bible/bible_database.dart';
import 'package:studyapp/services/service_locator.dart';

class BibleChapterManager {
  final _bibleDb = getIt<BibleDatabase>();

  final textNotifier = ValueNotifier<List<UsfmLine>>([]);

  Future<void> loadChapterData(int bookId, int chapter) async {
    // Determine if data is already loaded to avoid flicker?
    // For now, just fetch fresh data.
    textNotifier.value = await _bibleDb.getChapter(bookId, chapter);
  }

  void dispose() {
    textNotifier.dispose();
  }
}
