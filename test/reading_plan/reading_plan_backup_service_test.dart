import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/data_access/verse_state_repository.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/reading_plan/reading_plan_backup_service.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';

typedef _BookStatsSnapshot = ({
  int totalVerses,
  int versesRead,
  DateTime? lastRead,
  Reference? resumePosition,
});

_BookStatsSnapshot _snapshotOf(BookStats stats) => (
  totalVerses: stats.totalVerses,
  versesRead: stats.versesRead,
  lastRead: stats.lastRead,
  resumePosition: stats.resumePosition,
);

Matcher _formatError(String messagePart) => isA<FormatException>().having(
  (error) => error.message,
  'message',
  contains(messagePart),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late ReadingPlanBackupService backupService;
  late Directory tempDir;
  late Directory backupDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = ReadingSessionDatabase(
      databasePath: inMemoryDatabasePath,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.init();
    getIt.registerSingleton<ReadingSessionDatabase>(database);
    planService = ReadingPlanService();

    tempDir = await Directory.systemTemp.createTemp(
      'reading_plan_backup_test_',
    );
    backupDir = Directory(p.join(tempDir.path, 'backups'));
    backupService = ReadingPlanBackupService(backupDirectory: backupDir);
  });

  tearDown(() async {
    database.dispose();
    await getIt.reset();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<int> createPlan({
    String name = 'Test Plan',
    GoalType goalType = GoalType.verses,
    int goalValue = 5,
    List<int> bookIds = const [63],
  }) {
    return planService.saveReadingPlan(
      planName: name,
      goalType: goalType,
      goalValue: goalValue,
      bookIds: bookIds,
    );
  }

  Future<Session> insertSession({
    required int planId,
    required DateTime start,
    int readSeconds = 0,
    int verses = 0,
    bool isManual = false,
  }) {
    return database.session.commit(
      Session(
        rsDate: dayOnly(start),
        startTime: start,
        endTime: start.add(Duration(seconds: readSeconds)),
        readSeconds: readSeconds,
        verses: verses,
        readingPlanId: planId,
        isManual: isManual,
      ),
    );
  }

  Future<SessionLogEntry> insertLog(
    Session session, {
    required int bookId,
    int chapter = 1,
    int verse = 1,
    DateTime? at,
  }) async {
    final dateTime = at ?? session.startTime;
    final id = await database.sessionLog.append(
      SessionLogEntry(
        sessionId: session.id!,
        readingPlanId: session.readingPlanId,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        dateTime: dateTime,
      ),
    );
    return (await database.sessionLog.listForSession(
      session.id!,
    )).singleWhere((entry) => entry.id == id);
  }

  Future<Map<int, _BookStatsSnapshot>> bookStats(int planId) async {
    final stats = await database.verseState.getBookStats(planId);
    return {
      for (final entry in stats.entries) entry.key: _snapshotOf(entry.value),
    };
  }

  String backupJson(int formatVersion, Map<String, Object?> tables) {
    return jsonEncode({
      'format_version': formatVersion,
      'created_at': '2026-05-01T00:00:00.000',
      'tables': tables,
    });
  }

  Future<ReadingSessionBackupInfo> infoFor(File file) async {
    final stat = await file.stat();
    return ReadingSessionBackupInfo(
      path: file.path,
      name: p.basename(file.path),
      modifiedAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  group('backup files', () {
    test(
      'buildBackupBytes writes a v2 payload with all backup tables',
      () async {
        final planA = await createPlan(name: 'Plan A', bookIds: [63, 64]);
        await planService.setReadingPlanBookmark(planA, true);
        final planB = await createPlan(
          name: 'Plan B',
          goalType: GoalType.minutes,
          goalValue: 10,
          bookIds: [65],
        );
        final day = dayOnly(DateTime.now());
        final sessionA = await insertSession(
          planId: planA,
          start: day.add(const Duration(hours: 8)),
          readSeconds: 300,
          verses: 2,
        );
        final sessionB = await insertSession(
          planId: planB,
          start: day.add(const Duration(hours: 9)),
          readSeconds: 60,
          verses: 1,
          isManual: true,
        );
        await insertLog(sessionA, bookId: 63, verse: 1);
        await insertLog(sessionA, bookId: 63, verse: 2);
        await insertLog(sessionB, bookId: 65, verse: 1);
        await database.daySummary.upsert(planA, day);
        await database.daySummary.upsert(planB, day);

        final before = DateTime.now();
        final bytes = await backupService.buildBackupBytes();
        final after = DateTime.now();

        final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        expect(payload['format_version'], 2);
        final createdAt = DateTime.parse(payload['created_at'] as String);
        expect(createdAt.isBefore(before), isFalse);
        expect(createdAt.isAfter(after), isFalse);

        final tables = payload['tables'] as Map<String, dynamic>;
        expect(tables.keys.toSet(), {
          'reading_plan',
          'reading_plan_book',
          'rs_session',
          'rs_log',
          'rs_day_summary',
        });
        expect(tables, await backupService.exportTables());
      },
    );

    test(
      'createBackup writes a timestamped file in the backup directory',
      () async {
        final planId = await createPlan(name: 'File Backup');
        await backupService.createBackup();

        final files = backupDir.listSync().whereType<File>().toList();
        expect(files, hasLength(1));
        final file = files.single;
        expect(file.parent.path, backupDir.path);
        expect(
          p.basename(file.path),
          matches(RegExp(r'^reading_session_.*\.json$')),
        );

        final payload =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(payload['format_version'], 2);
        final tables = payload['tables'] as Map<String, dynamic>;
        final planRows = (tables['reading_plan'] as List).cast<Map>();
        expect(planRows.any((row) => row['id'] == planId), isTrue);
      },
    );

    test(
      'listBackups returns empty when the directory does not exist',
      () async {
        expect(await backupService.listBackups(), isEmpty);

        final missing = Directory(p.join(tempDir.path, 'missing', 'backups'));
        final missingService = ReadingPlanBackupService(
          backupDirectory: missing,
        );
        expect(await missingService.listBackups(), isEmpty);
        expect(await missing.exists(), isFalse);
      },
    );

    test('listBackups lists only JSON files newest first', () async {
      await backupDir.create(recursive: true);
      final older = File(p.join(backupDir.path, 'older.json'));
      final newer = File(p.join(backupDir.path, 'newer.json'));
      await older.writeAsString('{}');
      await newer.writeAsString('{"format_version":2}');
      await older.setLastModified(DateTime(2026, 1, 1, 10));
      await newer.setLastModified(DateTime(2026, 1, 1, 11));

      await File(p.join(backupDir.path, 'notes.txt')).writeAsString('ignored');
      await Directory(p.join(backupDir.path, 'nested.json')).create();

      expect(await backupService.listBackups(), [
        await infoFor(newer),
        await infoFor(older),
      ]);
    });

    test(
      'exportBackup creates parent directories and restoreBackup reads it',
      () async {
        final planId = await createPlan(name: 'File Restore');
        final before = (await database.readingPlans.getById(planId))!;
        final path = p.join(backupDir.path, 'nested', 'manual_backup.json');

        final exported = await backupService.exportBackup(path);

        expect(exported, path);
        expect(await File(path).exists(), isTrue);
        final payload =
            jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
        expect(payload['format_version'], 2);

        await planService.deleteReadingPlan(planId);
        expect(await database.readingPlans.getById(planId), isNull);

        await backupService.restoreBackup(path);

        expect(await database.readingPlans.getById(planId), before);
      },
    );
  });

  group('current format restore', () {
    test('restores plans, sessions, logs, and summaries exactly', () async {
      final planA = await createPlan(name: 'Plan A', bookIds: [63, 64]);
      await planService.setReadingPlanBookmark(planA, true);
      final planB = await createPlan(
        name: 'Plan B',
        goalType: GoalType.minutes,
        goalValue: 10,
        bookIds: [65],
      );
      final day1 = DateTime(2026, 11, 20);
      final day2 = DateTime(2026, 11, 21);
      final a1 = await insertSession(
        planId: planA,
        start: day1.add(const Duration(hours: 8)),
        readSeconds: 300,
        verses: 2,
      );
      final a2 = await insertSession(
        planId: planA,
        start: day2.add(const Duration(hours: 9)),
        readSeconds: 60,
        verses: 1,
        isManual: true,
      );
      final b1 = await insertSession(
        planId: planB,
        start: day1.add(const Duration(hours: 10)),
        readSeconds: 600,
        verses: 5,
      );
      await insertLog(a1, bookId: 63, verse: 1);
      await insertLog(a1, bookId: 63, verse: 2);
      await insertLog(a2, bookId: 64, verse: 1);
      await insertLog(b1, bookId: 65, verse: 1);
      await database.daySummary.upsert(planA, day1);
      await database.daySummary.upsert(planA, day2);
      await database.daySummary.upsert(planB, day1);

      final plansBefore = await database.readingPlans.list();
      final sessionsBefore = await database.session.exportAll();
      final logsBefore = await database.sessionLog.exportAll();
      final summariesBefore = await database.daySummary.exportAll();

      final bytes = await backupService.buildBackupBytes();
      await planService.deleteReadingPlan(planA);
      await backupService.restoreBackupBytes(bytes);

      expect(await database.readingPlans.list(), plansBefore);
      expect(await database.session.exportAll(), sessionsBefore);
      expect(await database.sessionLog.exportAll(), logsBefore);
      expect(await database.daySummary.exportAll(), summariesBefore);
    });

    test('restore replaces existing data instead of merging', () async {
      final planId = await createPlan(name: 'Kept Plan');
      final day = DateTime(2026, 11, 20);
      final session = await insertSession(
        planId: planId,
        start: day.add(const Duration(hours: 8)),
        readSeconds: 120,
        verses: 1,
      );
      await insertLog(session, bookId: 63);
      await database.daySummary.upsert(planId, day);
      await database.verseState.markRead(
        planId,
        63,
        1,
        1,
        timestamp: DateTime(2026, 11, 20, 8),
      );
      final keptPlan = (await database.readingPlans.getById(planId))!;

      final bytes = await backupService.buildBackupBytes();

      final extraPlan = await createPlan(name: 'Extra Plan', bookIds: [66]);
      final extraSession = await insertSession(
        planId: extraPlan,
        start: day.add(const Duration(hours: 11)),
        readSeconds: 60,
        verses: 2,
      );
      await insertLog(extraSession, bookId: 66);
      await database.daySummary.upsert(extraPlan, day);
      await database.verseState.markRead(extraPlan, 66, 1, 1);

      await backupService.restoreBackupBytes(bytes);

      expect(await database.readingPlans.getById(planId), keptPlan);
      expect(await database.readingPlans.getById(extraPlan), isNull);
      expect(await database.session.listForDate(day, extraPlan), isEmpty);
      expect(
        await database.sessionLog.listForSession(extraSession.id!),
        isEmpty,
      );
      expect(await database.daySummary.get(extraPlan, day), isNull);
      expect(await bookStats(extraPlan), isEmpty);
      expect(await database.verseState.getBookStats(extraPlan), isEmpty);
      expect(
        await database.verseState.getReadCount(extraPlan, 66, 1, 1),
        isNull,
      );
    });

    test(
      'rebuilds verse state from logs and materializes unread verses',
      () async {
        await backupService.restoreBackupJson(
          backupJson(2, {
            'reading_plan': [
              {
                'id': 5,
                'plan_name': 'Verse State',
                'created_at': '2026-04-01T00:00:00.000',
                'goal_type': 'verses',
                'goal_value': 5,
                'is_bookmarked': 0,
              },
            ],
            'reading_plan_book': [
              {'reading_plan_id': 5, 'book_id': 63, 'ord': 1},
            ],
            'rs_session': [
              {
                'id': 1,
                'rs_date': '2026-11-20',
                'start_time': '2026-11-20T09:00:00.000',
                'end_time': '2026-11-20T09:05:00.000',
                'read_seconds': 300,
                'verses': 3,
                'reading_plan_id': 5,
                'is_manual': 0,
              },
            ],
            'rs_log': [
              {
                'id': 1,
                'rs_session_id': 1,
                'reading_plan_id': 5,
                'book_id': 63,
                'chapter': 1,
                'verse': 1,
                'date_time': '2026-11-20T09:01:00.000',
              },
              {
                'id': 2,
                'rs_session_id': 1,
                'reading_plan_id': 5,
                'book_id': 63,
                'chapter': 1,
                'verse': 1,
                'date_time': '2026-11-20T09:02:00.000',
              },
              {
                'id': 3,
                'rs_session_id': 1,
                'reading_plan_id': 5,
                'book_id': 63,
                'chapter': 1,
                'verse': 2,
                'date_time': '2026-11-20T09:03:00.000',
              },
            ],
            'rs_day_summary': [],
            'rs_verse_state': [
              {
                'reading_plan_id': 5,
                'book_id': 63,
                'chapter': 1,
                'verse': 1,
                'read_count': 99,
                'last_read': '2026-11-20T09:09:00.000',
              },
            ],
          }),
        );

        expect(await database.verseState.getReadCount(5, 63, 1, 1), 2);
        expect(await database.verseState.getReadCount(5, 63, 1, 2), 1);
        expect(await database.verseState.getReadCount(5, 63, 1, 3), 0);
        expect((await bookStats(5))[63], (
          totalVerses: 13,
          versesRead: 2,
          lastRead: DateTime.parse('2026-11-20T09:03:00.000'),
          resumePosition: const Reference(bookId: 63, chapter: 1, verse: 3),
        ));
      },
    );

    test('preserves stored day summary goal snapshots', () async {
      await backupService.restoreBackupJson(
        backupJson(2, {
          'reading_plan': [
            {
              'id': 5,
              'plan_name': 'Summary Snapshot',
              'created_at': '2026-04-01T00:00:00.000',
              'goal_type': 'minutes',
              'goal_value': 10,
              'is_bookmarked': 0,
            },
          ],
          'reading_plan_book': [
            {'reading_plan_id': 5, 'book_id': 63, 'ord': 1},
          ],
          'rs_session': [],
          'rs_log': [],
          'rs_day_summary': [
            {
              'reading_plan_id': 5,
              'rs_date': '2026-11-20',
              'rs_seconds': 60,
              'rs_verses': 2,
              'goal_type': 'verses',
              'goal_value': 7,
              'goal_reached': 1,
            },
          ],
        }),
      );

      expect(
        await database.daySummary.get(5, DateTime(2026, 11, 20)),
        DaySummary(
          readingPlanId: 5,
          rsDate: DateTime(2026, 11, 20),
          rsSeconds: 60,
          rsVerses: 2,
          goalType: GoalType.verses,
          goalValue: 7,
          goalReached: true,
        ),
      );
    });

    test('rejects malformed backup envelopes', () async {
      await expectLater(
        backupService.restoreBackupJson('not json'),
        throwsFormatException,
      );
      await expectLater(
        backupService.restoreBackupJson('[]'),
        throwsA(_formatError('Invalid backup file.')),
      );
      await expectLater(
        backupService.restoreBackupJson(jsonEncode({'format_version': 2})),
        throwsA(_formatError('Backup is missing table data.')),
      );
      await expectLater(
        backupService.restoreBackupJson(
          jsonEncode({'tables': <String, Object?>{}}),
        ),
        throwsA(_formatError('Backup is missing version data.')),
      );
      await expectLater(
        backupService.restoreBackupJson(
          jsonEncode({'format_version': '2', 'tables': <String, Object?>{}}),
        ),
        throwsA(_formatError('Backup is missing version data.')),
      );
    });

    test('rejects payloads missing a required table', () async {
      final baseTables = <String, Object?>{
        'reading_plan': <Object?>[],
        'reading_plan_book': <Object?>[],
        'rs_session': <Object?>[],
        'rs_log': <Object?>[],
        'rs_day_summary': <Object?>[],
      };

      for (final missing in baseTables.keys) {
        final tables = Map<String, Object?>.from(baseTables)..remove(missing);
        await expectLater(
          backupService.restoreBackupJson(backupJson(2, tables)),
          throwsA(
            _formatError('Backup table payload for $missing is invalid.'),
          ),
          reason: 'missing $missing',
        );
      }
    });

    test(
      'a failed restore leaves every table and verse state untouched',
      () async {
        final planId = await createPlan(name: 'Survivor');
        final day = DateTime(2026, 11, 20);
        final session = await insertSession(
          planId: planId,
          start: day.add(const Duration(hours: 8)),
          readSeconds: 600,
          verses: 4,
        );
        await insertLog(session, bookId: 63, verse: 1);
        await database.daySummary.upsert(planId, day);
        await database.verseState.markRead(
          planId,
          63,
          1,
          1,
          timestamp: DateTime(2026, 11, 20, 8),
        );

        final plansBefore = await database.readingPlans.list();
        final sessionsBefore = await database.session.exportAll();
        final logsBefore = await database.sessionLog.exportAll();
        final summariesBefore = await database.daySummary.exportAll();
        final statsBefore = await bookStats(planId);
        final readCountBefore = await database.verseState.getReadCount(
          planId,
          63,
          1,
          1,
        );

        final tables = await backupService.exportTables()
          ..remove('rs_day_summary');

        await expectLater(
          backupService.restoreBackupJson(backupJson(2, tables)),
          throwsA(_formatError('rs_day_summary')),
        );

        expect(await database.readingPlans.list(), plansBefore);
        expect(await database.session.exportAll(), sessionsBefore);
        expect(await database.sessionLog.exportAll(), logsBefore);
        expect(await database.daySummary.exportAll(), summariesBefore);
        expect(await bookStats(planId), statsBefore);
        expect(
          await database.verseState.getReadCount(planId, 63, 1, 1),
          readCountBefore,
        );
      },
    );
  });

  group('v1 restore', () {
    test('creates the Whole Bible plan and remaps sessions and logs', () async {
      final before = DateTime.now();
      await backupService.restoreBackupJson(
        backupJson(1, {
          'rs_daily_log': [
            {
              'id': 1,
              'rs_date': '2026-04-30',
              'start_time': '2026-04-30T09:00:00.000',
              'end_time': '2026-04-30T09:20:00.000',
              'verses': 3,
            },
            {
              'id': 2,
              'rs_date': '2026-05-01',
              'start_time': '2026-05-01T10:00:00.000',
              'end_time': '2026-05-01T10:00:30.000',
              'verses': 1,
            },
          ],
          'rs_log': [
            {
              'id': 1,
              'rs_daily_log_id': 1,
              'book_id': 1,
              'chapter': 1,
              'verse': 1,
              'date_time': '2026-04-30T09:05:00.000',
            },
            {
              'id': 2,
              'rs_daily_log_id': 1,
              'book_id': 1,
              'chapter': 1,
              'verse': 1,
              'date_time': '2026-04-30T09:10:00.000',
            },
            {
              'id': 3,
              'rs_daily_log_id': 2,
              'book_id': 1,
              'chapter': 1,
              'verse': 2,
              'date_time': '2026-05-01T10:01:00.000',
            },
          ],
          'rs_stats': <Object?>[],
          'rs_book_progress': [
            {
              'id': 1,
              'book_id': 1,
              'chapter': 1,
              'verse': 15,
              'chapters_read': 0,
              'verses_read': 99,
              'updated_at': '2026-04-30T09:20:00.000',
            },
          ],
        }),
      );
      final after = DateTime.now();

      final plan = (await database.readingPlans.getById(1))!;
      expect(plan.createdAt.isBefore(before), isFalse);
      expect(plan.createdAt.isAfter(after), isFalse);
      expect(
        plan,
        ReadingPlan(
          id: 1,
          planName: 'Whole Bible',
          createdAt: plan.createdAt,
          goalType: GoalType.minutes,
          goalValue: 10,
          isBookmarked: false,
          bookIds: [for (var bookId = 1; bookId <= 66; bookId++) bookId],
        ),
      );

      expect(
        await database.session.getById(1),
        Session(
          id: 1,
          rsDate: DateTime.parse('2026-04-30'),
          startTime: DateTime.parse('2026-04-30T09:00:00.000'),
          endTime: DateTime.parse('2026-04-30T09:20:00.000'),
          readSeconds: 20 * 60,
          verses: 3,
          readingPlanId: 1,
          isManual: false,
        ),
      );
      expect(
        await database.session.getById(2),
        Session(
          id: 2,
          rsDate: DateTime.parse('2026-05-01'),
          startTime: DateTime.parse('2026-05-01T10:00:00.000'),
          endTime: DateTime.parse('2026-05-01T10:00:30.000'),
          readSeconds: 30,
          verses: 1,
          readingPlanId: 1,
          isManual: false,
        ),
      );

      expect(await database.sessionLog.listForSession(1), [
        SessionLogEntry(
          id: 1,
          sessionId: 1,
          readingPlanId: 1,
          bookId: 1,
          chapter: 1,
          verse: 1,
          dateTime: DateTime.parse('2026-04-30T09:05:00.000'),
        ),
        SessionLogEntry(
          id: 2,
          sessionId: 1,
          readingPlanId: 1,
          bookId: 1,
          chapter: 1,
          verse: 1,
          dateTime: DateTime.parse('2026-04-30T09:10:00.000'),
        ),
      ]);
      expect(await database.sessionLog.listForSession(2), [
        SessionLogEntry(
          id: 3,
          sessionId: 2,
          readingPlanId: 1,
          bookId: 1,
          chapter: 1,
          verse: 2,
          dateTime: DateTime.parse('2026-05-01T10:01:00.000'),
        ),
      ]);
    });

    test(
      'rebuilds summaries from stats flags with a computed fallback',
      () async {
        await backupService.restoreBackupJson(
          backupJson(1, {
            'rs_daily_log': [
              {
                'id': 1,
                'rs_date': '2026-04-30',
                'start_time': '2026-04-30T09:00:00.000',
                'end_time': '2026-04-30T09:01:00.000',
                'verses': 1,
              },
              {
                'id': 2,
                'rs_date': '2026-05-01',
                'start_time': '2026-05-01T10:00:00.000',
                'end_time': '2026-05-01T10:20:00.000',
                'verses': 12,
              },
            ],
            'rs_log': <Object?>[],
            'rs_stats': [
              {
                'id': 1,
                'type': 'D',
                'stats_date': '2026-04-30T00:00:00.000',
                'rs_seconds': 999,
                'rs_verses': 999,
                'goal_reached': 1,
              },
              {
                'id': 2,
                'type': 'M',
                'stats_date': '2026-05-01T00:00:00.000',
                'rs_seconds': 999,
                'rs_verses': 999,
                'goal_reached': 0,
              },
            ],
          }),
        );

        expect(
          await database.daySummary.listBetween(
            1,
            DateTime(2026, 4, 30),
            DateTime(2026, 5, 1),
          ),
          [
            DaySummary(
              readingPlanId: 1,
              rsDate: DateTime(2026, 4, 30),
              rsSeconds: 60,
              rsVerses: 1,
              goalType: GoalType.minutes,
              goalValue: 10,
              goalReached: true,
            ),
            DaySummary(
              readingPlanId: 1,
              rsDate: DateTime(2026, 5, 1),
              rsSeconds: 20 * 60,
              rsVerses: 12,
              goalType: GoalType.minutes,
              goalValue: 10,
              goalReached: true,
            ),
          ],
        );
      },
    );

    test('rebuilds verse state from logs and materializes zeros', () async {
      await backupService.restoreBackupJson(
        backupJson(1, {
          'rs_daily_log': [
            {
              'id': 1,
              'rs_date': '2026-04-30',
              'start_time': '2026-04-30T09:00:00.000',
              'end_time': '2026-04-30T09:20:00.000',
              'verses': 3,
            },
          ],
          'rs_log': [
            {
              'id': 1,
              'rs_daily_log_id': 1,
              'book_id': 1,
              'chapter': 1,
              'verse': 1,
              'date_time': '2026-04-30T09:05:00.000',
            },
            {
              'id': 2,
              'rs_daily_log_id': 1,
              'book_id': 1,
              'chapter': 1,
              'verse': 1,
              'date_time': '2026-04-30T09:10:00.000',
            },
            {
              'id': 3,
              'rs_daily_log_id': 1,
              'book_id': 1,
              'chapter': 1,
              'verse': 2,
              'date_time': '2026-04-30T09:15:00.000',
            },
          ],
          'rs_stats': <Object?>[],
        }),
      );

      expect(await database.verseState.getReadCount(1, 1, 1, 1), 2);
      expect(await database.verseState.getReadCount(1, 1, 1, 2), 1);
      expect(await database.verseState.getReadCount(1, 1, 1, 3), 0);
      final stats = await bookStats(1);
      expect(stats.keys, hasLength(66));
      expect(stats[1], (
        totalVerses: 1533,
        versesRead: 2,
        lastRead: DateTime.parse('2026-04-30T09:15:00.000'),
        resumePosition: const Reference(bookId: 1, chapter: 1, verse: 3),
      ));
      expect(stats[63], (
        totalVerses: 13,
        versesRead: 0,
        lastRead: null,
        resumePosition: const Reference(bookId: 63, chapter: 1, verse: 1),
      ));
    });
  });
}
