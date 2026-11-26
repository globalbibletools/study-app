import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
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
    database = ReadingSessionDatabase.withDependencies(
      databasePath: inMemoryDatabasePath,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.init();
  });

  tearDown(() {
    database.dispose();
  });

  Session newSession(DateTime at) {
    return Session(
      rsDate: DateTime(at.year, at.month, at.day),
      startTime: at,
      endTime: at.add(const Duration(minutes: 5)),
      readSeconds: 300,
      verses: 1,
      readingPlanId: 1,
    );
  }

  SessionLogEntry newLog(Session session, DateTime at) {
    return SessionLogEntry(
      sessionId: session.id!,
      readingPlanId: session.readingPlanId,
      bookId: 63,
      chapter: 1,
      verse: 1,
      dateTime: at,
    );
  }

  test('commits every repository write when the closure succeeds', () async {
    final at = DateTime(2026, 11, 25, 9);

    final saved = await database.unitOfWork((uow) async {
      final session = await uow.session.commit(newSession(at));
      await uow.sessionLog.append(newLog(session, at));
      await uow.daySummary.upsert(session.readingPlanId, session.rsDate);
      return session;
    });

    expect(await database.session.getById(saved.id!), saved);
    expect(await database.sessionLog.listForSession(saved.id!), hasLength(1));
    expect(await database.daySummary.get(saved.readingPlanId, at), isNotNull);
  });

  test('rolls back every repository write when the closure throws', () async {
    final at = DateTime(2026, 11, 25, 9);

    await expectLater(
      database.unitOfWork((uow) async {
        final session = await uow.session.commit(newSession(at));
        await uow.sessionLog.append(newLog(session, at));
        await uow.daySummary.upsert(session.readingPlanId, session.rsDate);
        throw StateError('rollback');
      }),
      throwsStateError,
    );

    expect(await database.session.exportAll(), isEmpty);
    expect(await database.sessionLog.exportAll(), isEmpty);
    expect(await database.daySummary.exportAll(), isEmpty);
  });
}
