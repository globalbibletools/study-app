import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = ReadingSessionDatabase(
      databaseName: 'reading_plan_service_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    planService = ReadingPlanService.withDatabase(database);
  });

  tearDown(() {
    database.dispose();
  });

  test('creates, reads, updates, reorders, and deletes a plan', () async {
    final savedPlan = await planService.saveReadingPlan(
      planName: 'Service Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 15,
      selectedBookIds: {3, 1, 2},
    );

    final fetchedPlan = await planService.getReadingPlanById(savedPlan.id!);
    expect(fetchedPlan, isNotNull);
    expect(fetchedPlan!.readingPlan.planName, 'Service Test');
    expect(fetchedPlan.readingPlan.goalValue, 15);
    expect(fetchedPlan.books.map((b) => b.bookId), [1, 2, 3]);

    final bookmarkedPlan = await planService.setReadingPlanBookmark(
      fetchedPlan.readingPlan,
      true,
    );
    expect(bookmarkedPlan.isBookmarked, isTrue);

    final reloadedPlan = await planService.getReadingPlanById(savedPlan.id!);
    expect(reloadedPlan!.readingPlan.isBookmarked, isTrue);

    await planService.reorderReadingPlanBooks(
      savedPlan.id!,
      reloadedPlan.books.reversed.toList(),
    );

    final reorderedPlan = await planService.getReadingPlanById(savedPlan.id!);
    expect(reorderedPlan!.books.map((b) => b.bookId), [3, 2, 1]);
    expect(reorderedPlan.books.map((b) => b.ord), [1, 2, 3]);

    final allPlans = await planService.getReadingPlans();
    expect(
      allPlans.where((p) => p.readingPlan.id == savedPlan.id),
      hasLength(1),
    );

    await planService.deleteReadingPlan(savedPlan.id!);
    expect(await planService.getReadingPlanById(savedPlan.id!), isNull);
  });
}
