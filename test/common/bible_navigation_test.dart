import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('BibleNavigation.withCounts', () {
    test('derives chapter counts and book totals from per-chapter counts', () {
      final navigation = BibleNavigation.withCounts({
        (1, 1): 31,
        (1, 2): 25,
        (2, 1): 22,
      });

      expect(navigation.getChapterCount(1), 2);
      expect(navigation.getChapterCount(2), 1);
      expect(navigation.getTotalVerseCount(1), 56);
      expect(navigation.getTotalVerseCount(2), 22);
      expect(navigation.getVerseCount(1, 1), 31);
      expect(navigation.getVerseCount(1, 2), 25);
    });

    test('returns 0 for unknown books and chapters', () {
      final navigation = BibleNavigation.withCounts({(1, 1): 31});

      expect(navigation.getChapterCount(99), 0);
      expect(navigation.getTotalVerseCount(99), 0);
      expect(navigation.getVerseCount(99, 1), 0);
      expect(navigation.getVerseCount(1, 2), 0);
    });
  });

  group('BibleNavigation navigation', () {
    late BibleNavigation navigation;

    setUp(() {
      navigation = createTestBibleNavigation();
    });

    test('keeps canonical book counts hardcoded', () {
      expect(navigation.getBooksCount(), 66);
      expect(navigation.getNewTestamentBookId(), 40);
      expect(BibleNavigation.christianBooks.length, 66);
    });

    test('traverses chapter boundaries at the start of the Bible', () {
      expect(
        navigation.getPreviousChapter(const ChapterIdentifier(1, 1)),
        isNull,
      );
      expect(
        navigation.getNextChapter(const ChapterIdentifier(1, 50)),
        const ChapterIdentifier(2, 1),
      );
    });

    test('traverses chapter boundaries at the end of the Bible', () {
      expect(
        navigation.getPreviousChapter(const ChapterIdentifier(66, 1)),
        const ChapterIdentifier(65, 1),
      );
      expect(
        navigation.getNextChapter(const ChapterIdentifier(66, 22)),
        isNull,
      );
    });

    test('uses text versification for known chapter counts', () {
      expect(navigation.getChapterCount(64), 1);
      expect(navigation.getVerseCount(64, 1), 15);
      expect(navigation.getVerseCount(41, 16), 8);
      expect(navigation.getVerseCount(43, 8), 48);
      expect(navigation.getTotalVerseCount(40), 1067);
    });
  });

  test('BibleNavigation.create matches the hardcoded fixture', () async {
    final db = await HebrewGreekDatabase.create();
    final navigation = await BibleNavigation.create(db);
    final fixture = createTestBibleNavigation();

    for (var bookId = 1; bookId <= navigation.getBooksCount(); bookId++) {
      expect(
        navigation.getChapterCount(bookId),
        fixture.getChapterCount(bookId),
        reason: 'chapter count for book $bookId',
      );
      expect(
        navigation.getTotalVerseCount(bookId),
        fixture.getTotalVerseCount(bookId),
        reason: 'total verse count for book $bookId',
      );

      final chapterCount = navigation.getChapterCount(bookId);
      for (var chapter = 1; chapter <= chapterCount; chapter++) {
        expect(
          navigation.getVerseCount(bookId, chapter),
          fixture.getVerseCount(bookId, chapter),
          reason: 'verse count for $bookId:$chapter',
        );
      }
    }
  });
}
