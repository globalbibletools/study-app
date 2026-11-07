import 'package:flutter/foundation.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';

@immutable
class ChapterIdentifier {
  final int bookId;
  final int chapter;

  const ChapterIdentifier(this.bookId, this.chapter);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterIdentifier &&
          runtimeType == other.runtimeType &&
          bookId == other.bookId &&
          chapter == other.chapter;

  @override
  int get hashCode => bookId.hashCode ^ chapter.hashCode;

  @override
  String toString() => '$bookId-$chapter';
}

class BibleNavigation {
  Map<int, int> _chapterCounts = const {};
  Map<(int, int), int> _verseCounts = const {};
  Map<int, int> _totalVerses = const {};

  static Future<BibleNavigation> create(HebrewGreekDatabase db) async {
    final counts = await db.getVersification();
    return BibleNavigation.withCounts(counts);
  }

  @visibleForTesting
  BibleNavigation.withCounts(Map<(int, int), int> verseCounts) {
    _applyVerseCounts(verseCounts);
  }

  void _applyVerseCounts(Map<(int, int), int> verseCounts) {
    final chapterCounts = <int, int>{};
    final totalVerses = <int, int>{};

    verseCounts.forEach((key, count) {
      final (bookId, chapter) = key;
      final currentMaxChapter = chapterCounts[bookId] ?? 0;
      if (chapter > currentMaxChapter) {
        chapterCounts[bookId] = chapter;
      }
      totalVerses[bookId] = (totalVerses[bookId] ?? 0) + count;
    });

    _verseCounts = Map.unmodifiable(verseCounts);
    _chapterCounts = Map.unmodifiable(chapterCounts);
    _totalVerses = Map.unmodifiable(totalVerses);
  }

  // Returns null if there is no previous chapter (e.g. Genesis 1)
  ChapterIdentifier? getPreviousChapter(ChapterIdentifier current) {
    // Case 1: Previous chapter in same book
    if (current.chapter > 1) {
      return ChapterIdentifier(current.bookId, current.chapter - 1);
    }
    // Case 2: Last chapter of previous book
    if (current.bookId > 1) {
      final previousBookId = current.bookId - 1;
      final lastChapterOfPreviousBook = getChapterCount(previousBookId);
      return ChapterIdentifier(previousBookId, lastChapterOfPreviousBook);
    }
    // Case 3: Start of Bible
    return null;
  }

  // Returns null if there is no next chapter (e.g. Revelation 22)
  ChapterIdentifier? getNextChapter(ChapterIdentifier current) {
    final totalChapters = getChapterCount(current.bookId);

    // Case 1: Next chapter in same book
    if (current.chapter < totalChapters) {
      return ChapterIdentifier(current.bookId, current.chapter + 1);
    }
    // Case 2: First chapter of next book
    if (current.bookId < getBooksCount()) {
      return ChapterIdentifier(current.bookId + 1, 1);
    }
    // Case 3: End of Bible
    return null;
  }

  // Returns null if there is no next chapter (last book in the reading plan)
  ChapterIdentifier? getNextChapterForReadingPlan(
    ChapterIdentifier current,
    ReadingPlanDetails readingPlan,
  ) {
    final totalChapters = getChapterCount(current.bookId);

    // Case 1: Next chapter in same book
    if (current.chapter < totalChapters) {
      return ChapterIdentifier(current.bookId, current.chapter + 1);
    }
    // Case 2: First chapter of next book
    for (int i = 0; i < readingPlan.books.length; i++) {
      if (readingPlan.books[i].bookId != current.bookId) continue;

      if (i < readingPlan.books.length - 1) {
        return ChapterIdentifier(readingPlan.books[i + 1].bookId, 1);
      }

      // Case 3 : End of the reading plan
      return null;
    }

    return null;
  }

  // Returns null if there is no previous chapter (e.g. Genesis 1)
  ChapterIdentifier? getPreviousChapterForReadingPlan(
    ChapterIdentifier current,
    ReadingPlanDetails readingPlan,
  ) {
    // Case 1: Previous chapter in same book
    if (current.chapter > 1) {
      return ChapterIdentifier(current.bookId, current.chapter - 1);
    }

    // Case 2: First chapter of previous book
    for (int i = 0; i < readingPlan.books.length; i++) {
      if (readingPlan.books[i].bookId != current.bookId) continue;

      // Case 3 : first book of the reading plan
      if (i == 0) return null;

      final previousBookId = readingPlan.books[i - 1].bookId;
      final lastChapterOfPreviousBook = getChapterCount(previousBookId);
      return ChapterIdentifier(previousBookId, lastChapterOfPreviousBook);
    }

    return null;
  }

  int getChapterCount(int bookId) {
    return _chapterCounts[bookId] ?? 0;
  }

  int getBooksCount() {
    return 66;
  }

  int getNewTestamentBookId() {
    return 40;
  }

  /// Total number of verses in [bookId] (sum across all its chapters).
  int getTotalVerseCount(int bookId) {
    return _totalVerses[bookId] ?? 0;
  }

  static const List<int> christianBooks = [
    1, // Genesis
    2, // Exodus
    3, // Leviticus
    4, // Numbers
    5, // Deuteronomy
    6, // Joshua
    7, // Judges
    8, // Ruth
    9, // 1 Samuel
    10, // 2 Samuel
    11, // 1 Kings
    12, // 2 Kings
    13, // 1 Chronicles
    14, // 2 Chronicles
    15, // Ezra
    16, // Nehemiah
    17, // Esther
    18, // Job
    19, // Psalms
    20, // Proverbs
    21, // Ecclesiastes
    22, // Song of Solomon
    23, // Isaiah
    24, // Jeremiah
    25, // Lamentations
    26, // Ezekiel
    27, // Daniel
    28, // Hosea
    29, // Joel
    30, // Amos
    31, // Obadiah
    32, // Jonah
    33, // Micah
    34, // Nahum
    35, // Habakkuk
    36, // Zephaniah
    37, // Haggai
    38, // Zechariah
    39, // Malachi
    40, // Matthew
    41, // Mark
    42, // Luke
    43, // John
    44, // Acts
    45, // Romans
    46, // 1 Corinthians
    47, // 2 Corinthians
    48, // Galatians
    49, // Ephesians
    50, // Philippians
    51, // Colossians
    52, // 1 Thessalonians
    53, // 2 Thessalonians
    54, // 1 Timothy
    55, // 2 Timothy
    56, // Titus
    57, // Philemon
    58, // Hebrews
    59, // James
    60, // 1 Peter
    61, // 2 Peter
    62, // 1 John
    63, // 2 John
    64, // 3 John
    65, // Jude
    66, // Revelation
  ];

  static const List<int> jewishBooks = [
    1, // Genesis
    2, // Exodus
    3, // Leviticus
    4, // Numbers
    5, // Deuteronomy
    6, // Joshua
    7, // Judges
    9, // 1 Samuel
    10, // 2 Samuel
    11, // 1 Kings
    12, // 2 Kings
    23, // Isaiah
    24, // Jeremiah
    26, // Ezekiel
    28, // Hosea
    29, // Joel
    30, // Amos
    31, // Obadiah
    32, // Jonah
    33, // Micah
    34, // Nahum
    35, // Habakkuk
    36, // Zephaniah
    37, // Haggai
    38, // Zechariah
    39, // Malachi
    19, // Psalms
    20, // Proverbs
    18, // Job
    22, // Song of Solomon
    8, // Ruth
    25, // Lamentations
    21, // Ecclesiastes
    17, // Esther
    27, // Daniel
    15, // Ezra
    16, // Nehemiah
    13, // 1 Chronicles
    14, // 2 Chronicles
  ];

  static const List<int> easyToHard = [
    32, // Jonah
    8, // Ruth
    1, // Genesis
    2, // Exodus
    6, // Joshua
    7, // Judges
    9, // 1 Samuel
    10, // 2 Samuel
    11, // 1 Kings
    12, // 2 Kings
    17, // Esther
    16, // Nehemiah
    15, // Ezra
    3, // Leviticus
    4, // Numbers
    5, // Deuteronomy
    13, // 1 Chronicles
    14, // 2 Chronicles
    27, // Daniel
    25, // Lamentations
    19, // Psalms
    20, // Proverbs
    21, // Ecclesiastes
    23, // Isaiah
    24, // Jeremiah
    26, // Ezekiel
    28, // Hosea
    29, // Joel
    30, // Amos
    31, // Obadiah
    33, // Micah
    34, // Nahum
    35, // Habakkuk
    36, // Zephaniah
    37, // Haggai
    38, // Zechariah
    39, // Malachi
    22, // Song of Solomon
    18, // Job

    62, // 1 John
    63, // 2 John
    64, // 3 John
    43, // John
    66, // Revelation
    41, // Mark
    40, // Matthew
    52, // 1 Thessalonians
    53, // 2 Thessalonians
    48, // Galatians
    50, // Philippians
    57, // Philemon
    46, // 1 Corinthians
    42, // Luke
    51, // Colossians
    49, // Ephesians
    45, // Romans
    59, // James
    60, // 1 Peter
    54, // 1 Timothy
    55, // 2 Timothy
    56, // Titus
    65, // Jude
    44, // Acts
    58, // Hebrews
    47, // 2 Corinthians
    61, // 2 Peter
  ];

  int getVerseCount(int bookId, int chapter) {
    return _verseCounts[(bookId, chapter)] ?? 0;
  }
}
