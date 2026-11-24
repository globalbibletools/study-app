import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/model.dart' show GoalType;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late int planId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<int> createPlan(String name, {List<int> bookIds = const [63, 1]}) {
    return database.readingPlans.commit(
      ReadingPlan(
        id: 0,
        planName: name,
        createdAt: DateTime(2026, 11, 20),
        goalType: GoalType.verses,
        goalValue: 10,
        isBookmarked: false,
        bookIds: bookIds,
      ),
    );
  }

  setUp(() async {
    database = ReadingSessionDatabase.withDependencies(
      databasePath: inMemoryDatabasePath,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.init();
    planId = await createPlan('Backup Row Test');
  });

  tearDown(() {
    database.dispose();
  });

  group('ReadingPlanRepository', () {
    test('exportAll orders plans by id and books by plan and ord', () async {
      await createPlan('Second Plan', bookIds: [2, 1]);

      final tables = await database.readingPlans.exportAll();

      final planIds = tables['reading_plan']!
          .map((row) => row['id'] as int)
          .toList();
      final sortedIds = [...planIds]..sort();
      expect(planIds, sortedIds);

      final bookKeys = tables['reading_plan_book']!
          .map((row) => [row['reading_plan_id'] as int, row['ord'] as int])
          .toList();
      final sortedKeys = [...bookKeys]
        ..sort((a, b) {
          final byPlan = a[0].compareTo(b[0]);
          return byPlan != 0 ? byPlan : a[1].compareTo(b[1]);
        });
      expect(bookKeys, sortedKeys);
    });

    test('importAll replaces the tables with the payload rows', () async {
      final exported = await database.readingPlans.exportAll();

      await createPlan('Extra Plan', bookIds: [5]);
      expect(
        (await database.readingPlans.list()).map((plan) => plan.planName),
        contains('Extra Plan'),
      );

      await database.transaction((txn) async {
        await database.readingPlans.importAll(exported, executor: txn);
      });

      final plans = await database.readingPlans.list();
      expect(plans.map((plan) => plan.planName), contains('Whole Bible'));
      expect(plans.map((plan) => plan.planName), isNot(contains('Extra Plan')));
      final restored = plans.singleWhere(
        (plan) => plan.planName == 'Backup Row Test',
      );
      expect(restored.bookIds, [63, 1]);
    });

    test('importAll ignores removed and unknown columns', () async {
      await database.transaction((txn) async {
        await database.readingPlans.importAll({
          'reading_plan': [
            {
              'id': 7,
              'plan_name': 'Legacy Columns',
              'created_at': '2026-04-01T00:00:00.000',
              'goal_type': 'M',
              'goal_value': 10,
              'is_bookmarked': 0,
              'collection_id': 4,
              'last_read': '2026-11-01T00:00:00.000',
              'future_column': 'ignored',
            },
          ],
          'reading_plan_book': [
            {
              'id': 99,
              'reading_plan_id': 7,
              'book_id': 1,
              'ord': 1,
              'future_column': 'ignored',
            },
          ],
        }, executor: txn);
      });

      final plan = await database.readingPlans.getById(7);
      expect(plan, isNotNull);
      expect(plan!.planName, 'Legacy Columns');
      expect(plan.bookIds, [1]);
    });

    test('importAll rejects a missing or malformed table', () async {
      await expectLater(
        database.transaction((txn) async {
          await database.readingPlans.importAll({}, executor: txn);
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('reading_plan'),
          ),
        ),
      );

      await expectLater(
        database.transaction((txn) async {
          await database.readingPlans.importAll({
            'reading_plan': [],
            'reading_plan_book': 'not a list',
          }, executor: txn);
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('reading_plan_book'),
          ),
        ),
      );
    });
  });

  group('SessionRepository', () {
    test('exportAll/importAll round-trips the sessions', () async {
      final date = DateTime(2026, 11, 20);
      await database.session.commit(
        Session(
          rsDate: date,
          startTime: DateTime(2026, 11, 20, 8),
          endTime: DateTime(2026, 11, 20, 8, 10),
          readSeconds: 600,
          verses: 4,
          readingPlanId: planId,
          isManual: true,
        ),
      );

      final exported = await database.session.exportAll();
      expect(exported, hasLength(1));
      final reimport = [
        for (final row in exported) {...row, 'future_column': 'ignored'},
      ];

      await database.session.commit(
        Session(
          rsDate: date,
          startTime: DateTime(2026, 11, 20, 9),
          readSeconds: 30,
          verses: 1,
          readingPlanId: planId,
        ),
      );
      expect(await database.session.exportAll(), hasLength(2));

      await database.transaction((txn) async {
        await database.session.importAll(reimport, executor: txn);
      });

      final restored = await database.session.listForDate(date, planId);
      expect(restored, hasLength(1));
      expect(restored.single.isManual, isTrue);
      expect(restored.single.readSeconds, 600);
      expect(restored.single.verses, 4);
    });

    test('importAll derives read_seconds from the timestamps', () async {
      await database.transaction((txn) async {
        await database.session.importAll([
          {
            'id': 1,
            'rs_date': '2026-04-30',
            'start_time': '2026-04-30T09:00:00.000',
            'end_time': '2026-04-30T09:20:00.000',
            'verses': 3,
            'reading_plan_id': planId,
            'future_column': 'ignored',
          },
          {
            'id': 2,
            'rs_date': '2026-04-30',
            'start_time': '2026-04-30T10:00:00.000',
            'end_time': '2026-04-30T10:00:30.000',
            'read_seconds': 'not a number',
            'verses': 1,
            'reading_plan_id': planId,
          },
          {
            'id': 3,
            'rs_date': '2026-04-30',
            'start_time': '2026-04-30T11:00:00.000',
            'end_time': '2026-04-30T10:59:00.000',
            'verses': 0,
            'reading_plan_id': planId,
          },
        ], executor: txn);
      });

      final sessions = await database.session.listForDate(
        DateTime(2026, 4, 30),
        planId,
      );
      expect(sessions.singleWhere((s) => s.id == 1).readSeconds, 20 * 60);
      expect(sessions.singleWhere((s) => s.id == 2).readSeconds, 30);
      expect(sessions.singleWhere((s) => s.id == 3).readSeconds, 0);
    });

    test('importAll defaults is_manual to 0 for older rows', () async {
      await database.transaction((txn) async {
        await database.session.importAll([
          {
            'id': 1,
            'rs_date': '2026-04-30',
            'start_time': '2026-04-30T09:00:00.000',
            'end_time': '2026-04-30T09:01:00.000',
            'read_seconds': 60,
            'verses': 1,
            'reading_plan_id': planId,
          },
        ], executor: txn);
      });

      final session = (await database.session.getById(1))!;
      expect(session.isManual, isFalse);
    });

    test('importAll rejects a malformed payload', () async {
      await expectLater(
        database.transaction((txn) async {
          await database.session.importAll('not a list', executor: txn);
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('rs_session'),
          ),
        ),
      );

      await expectLater(
        database.transaction((txn) async {
          await database.session.importAll(['not a map'], executor: txn);
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('rs_session'),
          ),
        ),
      );
    });
  });

  group('SessionLogRepository', () {
    test('exportAll/importAll round-trips the log rows', () async {
      final date = DateTime(2026, 11, 20);
      final session = await database.session.commit(
        Session(
          rsDate: date,
          startTime: DateTime(2026, 11, 20, 8),
          verses: 2,
          readingPlanId: planId,
        ),
      );
      for (var verse = 1; verse <= 2; verse++) {
        await database.sessionLog.append(
          SessionLogEntry(
            sessionId: session.id!,
            bookId: 63,
            chapter: 1,
            verse: verse,
            dateTime: DateTime(2026, 11, 20, 8, 0, verse),
            readingPlanId: planId,
          ),
        );
      }

      final exported = await database.sessionLog.exportAll();
      expect(exported, hasLength(2));
      final reimport = [
        for (final row in exported) {...row, 'future_column': 'ignored'},
      ];

      await database.sessionLog.remove(exported.first['id'] as int);
      expect(await database.sessionLog.exportAll(), hasLength(1));

      await database.transaction((txn) async {
        await database.sessionLog.importAll(reimport, executor: txn);
      });

      expect(
        await database.sessionLog.listForSession(session.id!),
        hasLength(2),
      );
    });

    test('importAll rejects a malformed payload', () async {
      await expectLater(
        database.transaction((txn) async {
          await database.sessionLog.importAll(null, executor: txn);
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('DaySummaryRepository', () {
    test('exportAll/importAll round-trips the day summaries', () async {
      final date = DateTime(2026, 11, 20);
      await database.session.commit(
        Session(
          rsDate: date,
          startTime: DateTime(2026, 11, 20, 8),
          endTime: DateTime(2026, 11, 20, 8, 10),
          readSeconds: 600,
          verses: 4,
          readingPlanId: planId,
        ),
      );
      await database.daySummary.upsert(planId, date);

      final exported = await database.daySummary.exportAll();
      expect(exported, hasLength(1));
      final reimport = [
        for (final row in exported) {...row, 'future_column': 'ignored'},
      ];

      await database.daySummary.deleteForDay(planId, date);
      await database.daySummary.upsert(planId, DateTime(2026, 11, 21));
      expect(await database.daySummary.exportAll(), hasLength(1));

      await database.transaction((txn) async {
        await database.daySummary.importAll(reimport, executor: txn);
      });

      final restored = await database.daySummary.listBetween(
        planId,
        DateTime(2026, 11, 20),
        DateTime(2026, 11, 21),
      );
      expect(restored, hasLength(1));
      expect(restored.single.rsDate, DateTime(2026, 11, 20));
      expect(restored.single.rsSeconds, 600);
    });

    test('importAll rejects a malformed payload', () async {
      await expectLater(
        database.transaction((txn) async {
          await database.daySummary.importAll(42, executor: txn);
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
