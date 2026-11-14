import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = ReadingSessionDatabase(
      databaseName: 'verse_state_queries_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
  });

  tearDown(() {
    database.dispose();
  });

  Future<int> createPlan(List<int> books) async {
    final plan = await database.saveReadingPlan(
      planName: 'Verse State Test',
      collectionId: 1,
      goalType: 'verses',
      goalValue: 10,
      orderedBookIds: books,
    );
    return plan.id!;
  }

  test(
    'increments and decrements read counts and last-read timestamps',
    () async {
      final planId = await createPlan([63]);

      await database.markVerseRead(planId, 63, 1, 1);
      await database.markVerseRead(planId, 63, 1, 1);
      await database.markVerseRead(planId, 63, 1, 2);

      var counts = await database.getVerseReadCountsForChapter(planId, 63, 1);
      expect(counts[1], 2);
      expect(counts[2], 1);
      expect(counts[3], 0);

      var aggregate = (await database.getBookStats(planId))[63]!;
      expect(aggregate.versesRead, 2);
      expect(aggregate.lastRead, isNotNull);

      await database.unmarkVerseRead(planId, 63, 1, 1);
      counts = await database.getVerseReadCountsForChapter(planId, 63, 1);
      expect(counts[1], 1);
      aggregate = (await database.getBookStats(planId))[63]!;
      expect(aggregate.versesRead, 2);

      await database.unmarkVerseRead(planId, 63, 1, 1);
      await database.unmarkVerseRead(planId, 63, 1, 1);
      counts = await database.getVerseReadCountsForChapter(planId, 63, 1);
      expect(counts[1], 0);
      aggregate = (await database.getBookStats(planId))[63]!;
      expect(aggregate.versesRead, 1);
    },
  );

  test('materializes provider inventory including numbering gaps', () async {
    database.dispose();
    database = ReadingSessionDatabase(
      databaseName: 'verse_state_gap_test.db',
      verseInventoryProvider: (bookIds) async {
        final inventory = createTestVerseInventory(bookIds: bookIds);
        if (bookIds.contains(40)) {
          inventory[(40, 16)] = [
            1,
            2,
            for (int verse = 4; verse <= 28; verse++) verse,
          ];
        }
        return inventory;
      },
    );
    await database.resetDatabase();
    await database.init();

    final planId = await createPlan([40]);

    final counts = await database.getVerseReadCountsForChapter(planId, 40, 16);
    expect(counts, hasLength(27));
    expect(counts.containsKey(3), isFalse);
    expect(counts[1], 0);
    expect(counts[28], 0);

    final aggregate = (await database.getBookStats(planId))[40]!;
    expect(aggregate.totalVerses, 1067);
  });
  test('book completion and verse unmark update completion state', () async {
    final planId = await createPlan([63, 64]);

    for (int verse = 1; verse <= 13; verse++) {
      await database.markVerseRead(planId, 63, 1, verse);
    }

    expect(await database.isBookComplete(planId, 63), isTrue);
    expect((await database.getBookStats(planId))[63]!.isComplete, isTrue);
    await database.unmarkVerseRead(planId, 63, 1, 7);
    expect(await database.isBookComplete(planId, 63), isFalse);
    expect((await database.getBookStats(planId))[63]!.versesRead, 12);
  });

  test(
    'getVerseReadStatesForChapter flags only the given session and deletes only that session log',
    () async {
      final planId = await createPlan([63]);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final firstSession = await database.insertSession(
        RsSession(
          rsDate: today,
          startTime: now,
          endTime: now,
          verses: 2,
          readingPlanId: planId,
        ),
      );
      final secondSession = await database.insertSession(
        RsSession(
          rsDate: today,
          startTime: now,
          endTime: now,
          verses: 0,
          readingPlanId: planId,
        ),
      );

      await database.markVerseRead(planId, 63, 1, 1);
      await database.markVerseRead(planId, 63, 1, 2);
      await database.insertLog(
        RsLog(
          sessionId: firstSession.id!,
          bookId: 63,
          chapter: 1,
          verse: 1,
          dateTime: now,
          readingPlanId: planId,
        ),
      );
      await database.insertLog(
        RsLog(
          sessionId: firstSession.id!,
          bookId: 63,
          chapter: 1,
          verse: 2,
          dateTime: now,
          readingPlanId: planId,
        ),
      );

      var states = await database.getVerseReadStatesForChapter(
        planId,
        firstSession.id!,
        63,
        1,
      );
      expect(states[1]!.readCount, 1);
      expect(states[1]!.readThisSession, isTrue);
      expect(states[2]!.readThisSession, isTrue);
      expect(states[3]!.readCount, 0);
      expect(states[3]!.readThisSession, isFalse);

      states = await database.getVerseReadStatesForChapter(
        planId,
        secondSession.id!,
        63,
        1,
      );
      expect(states[1]!.readCount, 1);
      expect(states[1]!.readThisSession, isFalse);
      expect(states[2]!.readThisSession, isFalse);

      await database.deleteRsLogForSessionAndVerse(firstSession.id!, 63, 1, 1);

      expect(
        await database.getRsLogForSessionAndVerse(firstSession.id!, 63, 1, 1),
        isEmpty,
      );
      expect(
        await database.getRsLogForSessionAndVerse(firstSession.id!, 63, 1, 2),
        hasLength(1),
      );
      expect(await database.getRsLogForSession(secondSession.id!), isEmpty);
    },
  );

  test(
    'removed books disappear from projections but keep their state',
    () async {
      final planId = await createPlan([63, 64]);
      for (int verse = 1; verse <= 15; verse++) {
        await database.markVerseRead(planId, 64, 1, verse);
      }
      expect(await database.isBookComplete(planId, 64), isTrue);

      var details = await database.getReadingPlanById(planId);
      await database.saveReadingPlan(
        existingPlan: details!.readingPlan,
        planName: 'Verse State Test',
        collectionId: 1,
        goalType: 'verses',
        goalValue: 10,
        orderedBookIds: [63],
      );

      var aggregates = await database.getBookStats(planId);
      expect(aggregates.containsKey(64), isFalse);
      expect(aggregates.containsKey(63), isTrue);
      expect(await database.isBookComplete(planId, 64), isTrue);

      details = await database.getReadingPlanById(planId);
      await database.saveReadingPlan(
        existingPlan: details!.readingPlan,
        planName: 'Verse State Test',
        collectionId: 1,
        goalType: 'verses',
        goalValue: 10,
        orderedBookIds: [63, 64],
      );

      aggregates = await database.getBookStats(planId);
      expect(aggregates[64]!.versesRead, 15);
      expect(await database.isBookComplete(planId, 64), isTrue);
    },
  );
}
