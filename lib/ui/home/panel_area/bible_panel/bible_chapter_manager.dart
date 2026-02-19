import 'package:flutter/foundation.dart';
import 'package:scripture/scripture.dart'; // For UsfmLine
import 'package:studyapp/services/bible/bible_service.dart';
import 'package:studyapp/services/service_locator.dart';

class BibleChapterManager {
  final _bibleService = getIt<BibleService>();
  final textNotifier = ValueNotifier<List<UsfmLine>>([]);

  Future<void> loadChapterData(int bookId, int chapter) async {
    textNotifier.value = await _bibleService.getChapter(bookId, chapter);
  }

  void dispose() {
    textNotifier.dispose();
  }
}
