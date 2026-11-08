import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/services/reading_session/reading_plan_backup_service.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanBackupService backupService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = ReadingSessionDatabase(
      databaseName: 'reading_plan_backup_service_test.db',
    );
    await database.resetDatabase();
    await database.init();
    backupService = ReadingPlanBackupService.withDatabase(database);
  });

  tearDown(() {
    database.dispose();
  });

  test('default constructor resolves the database from getIt', () async {
    if (getIt.isRegistered<ReadingSessionDatabase>()) {
      await getIt.unregister<ReadingSessionDatabase>();
    }
    addTearDown(() async {
      if (getIt.isRegistered<ReadingSessionDatabase>()) {
        await getIt.unregister<ReadingSessionDatabase>();
      }
    });
    getIt.registerSingleton<ReadingSessionDatabase>(database);

    final locatorService = ReadingPlanBackupService();

    final bytes = await locatorService.buildBackupBytes();
    final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(payload['format_version'], 2);
  });

  test('builds a versioned backup and restores it from bytes', () async {
    final initialPlanCount = (await database.getReadingPlans()).length;
    final plan = await database.saveReadingPlan(
      planName: 'Backup Test',
      collectionId: 1,
      goalType: 'verses',
      goalValue: 12,
      orderedBookIds: [1, 2],
    );

    final bytes = await backupService.buildBackupBytes();
    final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(payload['format_version'], 2);
    expect(
      (payload['tables'] as Map)['reading_plan'],
      hasLength(initialPlanCount + 1),
    );

    await database.deleteReadingPlan(plan.id!);
    expect(
      (await database.getReadingPlans()).where(
        (p) => p.readingPlan.planName == 'Backup Test',
      ),
      isEmpty,
    );

    await backupService.restoreBackupBytes(bytes);

    final restoredPlans = (await database.getReadingPlans()).where(
      (p) => p.readingPlan.planName == 'Backup Test',
    );
    expect(restoredPlans, hasLength(1));
    expect(restoredPlans.single.readingPlan.goalValue, 12);
    expect(restoredPlans.single.books.map((b) => b.bookId), [1, 2]);
  });
}
