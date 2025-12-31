import 'package:flutter/foundation.dart';

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
  // Returns null if there is no previous chapter (e.g. Genesis 1)
  static ChapterIdentifier? getPreviousChapter(ChapterIdentifier current) {
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
  static ChapterIdentifier? getNextChapter(ChapterIdentifier current) {
    final totalChapters = getChapterCount(current.bookId);

    // Case 1: Next chapter in same book
    if (current.chapter < totalChapters) {
      return ChapterIdentifier(current.bookId, current.chapter + 1);
    }
    // Case 2: First chapter of next book
    if (current.bookId < _bookIdToChapterCountMap.length) {
      return ChapterIdentifier(current.bookId + 1, 1);
    }
    // Case 3: End of Bible
    return null;
  }

  static int getChapterCount(int bookId) {
    return _bookIdToChapterCountMap[bookId] ?? 0;
  }

  // static const Map<int, int> _bookIdToChapterCountMap = {
  //   1: 50, 2: 40, 3: 27, 4: 36, 5: 34, 6: 24, 7: 21, 8: 4, 9: 31, 10: 24,
  //   11: 22, 12: 25, 13: 29, 14: 36, 15: 10, 16: 13, 17: 10, 18: 42, 19: 150, 20: 31,
  //   21: 12, 22: 8, 23: 66, 24: 52, 25: 5, 26: 48, 27: 12, 28: 14, 29: 3, 30: 9,
  //   31: 1, 32: 4, 33: 7, 34: 3, 35: 3, 36: 3, 37: 2, 38: 14, 39: 4, 40: 28,
  //   41: 16, 42: 24, 43: 21, 44: 28, 45: 16, 46: 16, 47: 13, 48: 6, 49: 6, 50: 4,
  //   51: 4, 52: 5, 53: 3, 54: 6, 55: 4, 56: 3, 57: 1, 58: 13, 59: 5, 60: 5,
  //   61: 3, 62: 5, 63: 1, 64: 1, 65: 1, 66: 22,
  // };

  static const Map<int, int> _bookIdToChapterCountMap = {
    1: 50, // Genesis
    2: 40, // Exodus
    3: 27, // Leviticus
    4: 36, // Numbers
    5: 34, // Deuteronomy
    6: 24, // Joshua
    7: 21, // Judges
    8: 4, // Ruth
    9: 31, // 1 Samuel
    10: 24, // 2 Samuel
    11: 22, // 1 Kings
    12: 25, // 2 Kings
    13: 29, // 1 Chronicles
    14: 36, // 2 Chronicles
    15: 10, // Ezra
    16: 13, // Nehemiah
    17: 10, // Esther
    18: 42, // Job
    19: 150, // Psalms
    20: 31, // Proverbs
    21: 12, // Ecclesiastes
    22: 8, // Song of Solomon
    23: 66, // Isaiah
    24: 52, // Jeremiah
    25: 5, // Lamentations
    26: 48, // Ezekiel
    27: 12, // Daniel
    28: 14, // Hosea
    29: 3, // Joel
    30: 9, // Amos
    31: 1, // Obadiah
    32: 4, // Jonah
    33: 7, // Micah
    34: 3, // Nahum
    35: 3, // Habakkuk
    36: 3, // Zephaniah
    37: 2, // Haggai
    38: 14, // Zechariah
    39: 4, // Malachi
    40: 28, // Matthew
    41: 16, // Mark
    42: 24, // Luke
    43: 21, // John
    44: 28, // Acts
    45: 16, // Romans
    46: 16, // 1 Corinthians
    47: 13, // 2 Corinthians
    48: 6, // Galatians
    49: 6, // Ephesians
    50: 4, // Philippians
    51: 4, // Colossians
    52: 5, // 1 Thessalonians
    53: 3, // 2 Thessalonians
    54: 6, // 1 Timothy
    55: 4, // 2 Timothy
    56: 3, // Titus
    57: 1, // Philemon
    58: 13, // Hebrews
    59: 5, // James
    60: 5, // 1 Peter
    61: 3, // 2 Peter
    62: 5, // 1 John
    63: 1, // 2 John
    64: 1, // 3 John
    65: 1, // Jude
    66: 22, // Revelation
  };
}
