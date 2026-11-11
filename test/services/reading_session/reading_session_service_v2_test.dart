import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/reading_session_service_v2.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/reading_plan/reading_session_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late ReadingSessionServiceV2 sessionService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
    getIt.registerSingleton<BibleNavigation>(createTestBibleNavigation());

    database = ReadingSessionDatabase(
      databaseName: 'reading_session_service_v2_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    planService = ReadingPlanService.withDatabase(database);
    sessionService = ReadingSessionServiceV2.withDatabase(database);
  });

  tearDown(() {
    database.dispose();
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
  });

  test('starts a session and returns a static plan config', () async {
    final plan = await planService.saveReadingPlan(
      planName: 'Session V2 Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 15,
      selectedBookIds: {63, 64},
    );

    final config = await sessionService.startSession(plan.id!);

    expect(config, isNotNull);
    expect(config!.planId, plan.id);
    expect(config.planName, 'Session V2 Test');
    expect(config.collectionId, 1);
    expect(config.dailyGoal.type, GoalType.verses);
    expect(config.dailyGoal.value, 15);
    expect(config.books.map((book) => book.bookId), [63, 64]);
    expect(config.bookIds, {63, 64});
    expect(config.totalChapters, 2);
    expect(config.totalVerses, 28);
    expect(() => config.books.add(config.books.first), throwsUnsupportedError);
  });

  test('returns null when the plan does not exist', () async {
    expect(await sessionService.startSession(999), isNull);
  });

  test('starts a session from a plan id and clears it on end', () async {
    final plan = await planService.saveReadingPlan(
      planName: 'Session V2 State Test',
      collectionId: 1,
      goalType: GoalType.minutes,
      goalValue: 20,
      selectedBookIds: {19},
    );

    final viewModel = ReadingSessionViewModel.withService(sessionService);

    expect(viewModel.planConfig, isNull);
    expect(viewModel.hasActiveSession, isFalse);

    await viewModel.startSession(plan.id!);

    expect(viewModel.hasActiveSession, isTrue);
    expect(viewModel.planConfig?.planId, plan.id);
    expect(viewModel.planConfig?.dailyGoal.type, GoalType.minutes);
    expect(viewModel.planConfig?.dailyGoal.value, 20);

    await viewModel.endSession();

    expect(viewModel.planConfig, isNull);
    expect(viewModel.hasActiveSession, isFalse);

    viewModel.dispose();
  });

  test('throws when starting a session for an unknown plan', () async {
    final viewModel = ReadingSessionViewModel.withService(sessionService);

    await expectLater(viewModel.startSession(999), throwsA(isA<StateError>()));
    expect(viewModel.hasActiveSession, isFalse);

    viewModel.dispose();
  });
}
