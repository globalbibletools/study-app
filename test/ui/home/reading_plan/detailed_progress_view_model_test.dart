import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/ui/home/reading_plan/detailed_progress_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/bible_navigation_fixture.dart';

/// Fails the first detailed-progress query, then delegates to the real
/// service so tests can observe the retry path.
class FlakyPlanService extends ReadingPlanService {
  FlakyPlanService(ReadingSessionDatabase database, {required this.failures})
    : super.withDependencies(
        database: database,
        bibleNavigation: createTestBibleNavigation(),
      );

  final int failures;
  int calls = 0;

  @override
  Future<List<SessionDetails>> getDetailedProgressFor(
    DateTime date,
    int readingPlanId,
  ) async {
    calls += 1;
    if (calls <= failures) {
      throw StateError('detailed progress query failed');
    }
    return super.getDetailedProgressFor(date, readingPlanId);
  }
}

/// Integration tests for [DetailedProgressViewModel] against a real in-memory
/// SQLite database and the real [ReadingPlanService]. Everything is injected
/// through `withDependencies`; the service locator is never used.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late DateTime date;

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
    planService = ReadingPlanService.withDependencies(
      database: database,
      bibleNavigation: createTestBibleNavigation(),
    );
    date = DateTime(2026, 11, 17);

    // The schema ships with a default "Whole Bible" plan (id 1). Remove it so
    // each test starts from a clean slate.
    for (final plan in await planService.getReadingPlans()) {
      await planService.deleteReadingPlan(plan.readingPlan.id!);
    }
  });

  tearDown(() {
    database.dispose();
  });

  Future<int> createPlan() async {
    final plan = await planService.saveReadingPlan(
      planName: 'Detailed Progress Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 10,
      selectedBookIds: {63},
    );
    return plan.id!;
  }

  Future<RsSession> insertSession(
    int planId, {
    int readSeconds = 0,
    int verses = 0,
    DateTime? startTime,
  }) {
    final start = startTime ?? DateTime(2026, 11, 17, 9);
    return database.insertSession(
      RsSession(
        rsDate: date,
        startTime: start,
        endTime: start.add(const Duration(minutes: 10)),
        readSeconds: readSeconds,
        verses: verses,
        readingPlanId: planId,
      ),
    );
  }

  Future<void> insertLog(
    RsSession session,
    int bookId,
    int chapter,
    int verse,
  ) {
    return database.insertLog(
      RsLog(
        sessionId: session.id!,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        dateTime: session.startTime,
        readingPlanId: session.readingPlanId,
      ),
    );
  }

  DetailedProgressViewModel newViewModel(int planId) {
    return DetailedProgressViewModel.withDependencies(
      readingPlanId: planId,
      date: date,
      planService: planService,
    );
  }

  test('loads sessions and derives totals for the requested day', () async {
    final planId = await createPlan();

    final first = await insertSession(planId, readSeconds: 600, verses: 3);
    await insertLog(first, 63, 1, 1);
    await insertLog(first, 63, 1, 2);
    await insertLog(first, 63, 1, 4);

    final second = await insertSession(
      planId,
      readSeconds: 300,
      verses: 2,
      startTime: DateTime(2026, 11, 17, 14),
    );
    await insertLog(second, 63, 2, 1);
    await insertLog(second, 63, 2, 2);

    final viewModel = newViewModel(planId);
    await viewModel.ready;

    expect(viewModel.readingPlanId, planId);
    expect(viewModel.date, date);
    expect(viewModel.sessionCount, 2);
    expect(viewModel.sessions, hasLength(2));
    expect(viewModel.totalSeconds, 900);
    expect(viewModel.totalMinutes, 15);
    expect(viewModel.totalVerses, 5);
    expect(viewModel.isRefreshing, isFalse);
    expect(viewModel.loadError, isNull);

    // Minutes are derived per session instead of in the widget.
    expect(viewModel.minutesFor(viewModel.sessions.first), 10);
    expect(viewModel.minutesFor(viewModel.sessions.last), 5);

    // Contiguous verses collapse into one range; 4 is separated by a gap.
    final progress = viewModel.sessions.first.progress;
    expect(progress, hasLength(2));
    expect((progress[0].fromVerse, progress[0].toVerse), (1, 2));
    expect((progress[1].fromVerse, progress[1].toVerse), (4, 4));
  });

  test('ignores sessions from other plans and days', () async {
    final planId = await createPlan();
    final otherPlan = await planService.saveReadingPlan(
      planName: 'Other Plan',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 10,
      selectedBookIds: {64},
    );

    final matching = await insertSession(planId, readSeconds: 60, verses: 1);
    await insertLog(matching, 63, 1, 1);

    final otherPlanSession = await insertSession(
      otherPlan.id!,
      readSeconds: 60,
      verses: 1,
    );
    await insertLog(otherPlanSession, 64, 1, 1);

    await database.insertSession(
      RsSession(
        rsDate: DateTime(2026, 11, 16),
        startTime: DateTime(2026, 11, 16, 9),
        endTime: DateTime(2026, 11, 16, 9, 10),
        readSeconds: 60,
        verses: 1,
        readingPlanId: planId,
      ),
    );

    final viewModel = newViewModel(planId);
    await viewModel.ready;

    expect(viewModel.sessionCount, 1);
    expect(viewModel.totalSeconds, 60);
    expect(viewModel.totalVerses, 1);
  });

  test('deduplicates concurrent refresh calls', () async {
    final planId = await createPlan();
    final viewModel = newViewModel(planId);
    await viewModel.ready;

    final first = viewModel.refresh();
    final second = viewModel.refresh();

    expect(identical(first, second), isTrue);
    await first;
  });

  test('captures a load error instead of throwing from ready', () async {
    final planId = await createPlan();
    final flaky = FlakyPlanService(database, failures: 1);
    final viewModel = DetailedProgressViewModel.withDependencies(
      readingPlanId: planId,
      date: date,
      planService: flaky,
    );

    await viewModel.ready;

    expect(viewModel.loadError, isA<StateError>());
    expect(viewModel.sessions, isEmpty);
    expect(viewModel.isRefreshing, isFalse);
  });

  test('refresh clears a previous load error', () async {
    final planId = await createPlan();
    final session = await insertSession(planId, readSeconds: 120, verses: 1);
    await insertLog(session, 63, 1, 1);

    final flaky = FlakyPlanService(database, failures: 1);
    final viewModel = DetailedProgressViewModel.withDependencies(
      readingPlanId: planId,
      date: date,
      planService: flaky,
    );
    await viewModel.ready;
    expect(viewModel.loadError, isNotNull);

    await viewModel.refresh();

    expect(viewModel.loadError, isNull);
    expect(viewModel.sessionCount, 1);
    expect(viewModel.totalSeconds, 120);
    expect(flaky.calls, 2);
  });
}
