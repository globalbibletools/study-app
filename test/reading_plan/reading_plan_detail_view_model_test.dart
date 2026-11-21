import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/reading_plan/reading_plan_detail_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';
import 'fake_reading_session_view_model.dart';

/// Fails bookmark persistence after yielding once, so tests can observe the
/// optimistic flip before the rollback.
class FailingBookmarkPlanService extends ReadingPlanService {
  FailingBookmarkPlanService(
    ReadingSessionDatabase database,
    BibleNavigation bibleNavigation,
  ) : super.withDependencies(
        database: database,
        bibleNavigation: bibleNavigation,
      );

  @override
  Future<ReadingPlan> setReadingPlanBookmark(
    ReadingPlan readingPlan,
    bool isBookmarked,
  ) async {
    await Future<void>.delayed(Duration.zero);
    throw StateError('bookmark write failed');
  }
}

/// Queues book-stat reads so tests can hold refreshes in flight.
class QueuedStatsPlanService extends ReadingPlanService {
  QueuedStatsPlanService(
    ReadingSessionDatabase database,
    BibleNavigation bibleNavigation,
  ) : super.withDependencies(
        database: database,
        bibleNavigation: bibleNavigation,
      );

  final statsRequests = <Completer<List<RsBookStats>>>[];

  @override
  Future<List<RsBookStats>> getBooksStats(int readingPlanId) {
    final request = Completer<List<RsBookStats>>();
    statsRequests.add(request);
    return request.future;
  }
}

/// Returns only the stats row that exists, exercising sparse-stat handling.
class SparseStatsPlanService extends ReadingPlanService {
  SparseStatsPlanService(
    ReadingSessionDatabase database,
    BibleNavigation bibleNavigation,
  ) : super.withDependencies(
        database: database,
        bibleNavigation: bibleNavigation,
      );

  @override
  Future<List<RsBookStats>> getBooksStats(int readingPlanId) async {
    final stats = await super.getBooksStats(readingPlanId);
    return stats.where((stat) => stat.bookId == 63).toList();
  }
}

/// Integration tests for [ReadingPlanDetailViewModel] running against a real
/// in-memory SQLite database, the real [ReadingPlanService], and a
/// [BibleNavigation] backed by the versification fixture.
///
/// Everything is injected through `withDependencies`; the service locator is
/// never used. Session start and reader navigation are faked because their
/// concerns are covered by the sibling panel view model tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late BibleNavigation bibleNavigation;
  late FakeReadingSessionViewModel sessionViewModel;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    bibleNavigation = createTestBibleNavigation();
    database = ReadingSessionDatabase.withDependencies(
      databasePath: inMemoryDatabasePath,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.init();
    planService = ReadingPlanService.withDependencies(
      database: database,
      bibleNavigation: bibleNavigation,
    );
    sessionViewModel = FakeReadingSessionViewModel();

    // The schema ships with a default "Whole Bible" plan (id 1). Remove it so
    // each test starts from a clean slate.
    for (final plan in await planService.getReadingPlans()) {
      await planService.deleteReadingPlan(plan.readingPlan.id!);
    }
  });

  tearDown(() {
    database.dispose();
  });

  ReadingPlanDetailViewModel newViewModel(
    ReadingPlanDetails plan, {
    ReadingPlanService? service,
  }) {
    return ReadingPlanDetailViewModel.withDependencies(
      plan: plan,
      planService: service ?? planService,
      sessionViewModel: sessionViewModel,
    );
  }

  Future<ReadingPlanDetails> savePlan({
    String name = 'Saved Plan',
    int collectionId = 1,
    GoalType goalType = GoalType.verses,
    int goalValue = 10,
    Set<int> bookIds = const {1, 2},
  }) async {
    final saved = await planService.saveReadingPlan(
      planName: name,
      collectionId: collectionId,
      goalType: goalType,
      goalValue: goalValue,
      selectedBookIds: bookIds,
    );
    final details = await planService.getReadingPlanById(saved.id!);
    return details!;
  }

  group('refresh', () {
    test(
      'aggregates progress by book stats and derives today\'s goal progress',
      () async {
        final details = await savePlan(bookIds: {63, 64}); // 13 + 15 verses
        final planId = details.readingPlan.id!;

        for (int verse = 1; verse <= 13; verse++) {
          await database.markVerseRead(planId, 63, 1, verse);
        }

        final now = DateTime.now();
        await database.insertSession(
          RsSession(
            rsDate: DateTime(now.year, now.month, now.day),
            startTime: now.subtract(const Duration(minutes: 10)),
            endTime: now,
            readSeconds: 600,
            verses: 13,
            readingPlanId: planId,
          ),
        );
        await database.upsertDaySummary(planId, now);

        final viewModel = newViewModel(details);
        await viewModel.initialize();

        expect(viewModel.totalVerses, 28);
        expect(viewModel.versesRead, 13);
        expect(viewModel.booksRead, 1);
        expect(viewModel.bookStats[63]!.versesRead, 13);
        expect(viewModel.bookStats.containsKey(999), isFalse);

        expect(viewModel.overallProgress, closeTo(13 / 28, 1e-9));
        expect(viewModel.progressPercent, 46);

        expect(viewModel.todaysProgress, isNotNull);
        expect(viewModel.todaysProgress!.verses, 13);
        expect(viewModel.todaysProgress!.minutes, 10);
        expect(viewModel.todaysGoalProgress, closeTo(1.3, 1e-9));
        expect(viewModel.goalReachedToday, isTrue);
      },
    );

    test('a newer refresh cancels the in-flight one and wins', () async {
      final details = await savePlan(bookIds: {8});
      final service = QueuedStatsPlanService(database, bibleNavigation);
      final viewModel = newViewModel(details, service: service);
      addTearDown(viewModel.dispose);

      final first = viewModel.initialize();
      final second = viewModel.refresh();

      expect(service.statsRequests, hasLength(2));

      service.statsRequests[0].complete(const []);
      await expectLater(first, throwsA(isA<CancelledError>()));

      service.statsRequests[1].complete([
        RsBookStats(bookId: 8, totalVerses: 85, versesRead: 85, lastRead: null),
      ]);
      await second;

      expect(viewModel.isInitialized, isTrue);
      expect(viewModel.versesRead, 85);
      expect(viewModel.isBookComplete(8), isTrue);
      expect(viewModel.hasStarted, isTrue);
    });

    test(
      'does not notify after dispose while a refresh is in flight',
      () async {
        final details = await savePlan(bookIds: {8});
        final service = QueuedStatsPlanService(database, bibleNavigation);
        final viewModel = newViewModel(details, service: service);
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        final future = viewModel.refresh();
        final notificationsBeforeDispose = notifications;

        viewModel.dispose();
        service.statsRequests.single.complete(const []);
        await expectLater(future, throwsA(isA<CancelledError>()));

        expect(notifications, notificationsBeforeDispose);
      },
    );

    test('loadMonthData replaces the calendar month data', () async {
      final details = await savePlan(bookIds: {8});
      final viewModel = newViewModel(details);
      await viewModel.initialize();

      await viewModel.loadMonthData(DateTime(2026, 11, 1));

      expect(viewModel.visibleMonth, DateTime(2026, 11));
      expect(viewModel.monthProgress.value, hasLength(30));
      expect(viewModel.monthProgress.value.first.day, DateTime(2026, 11, 1));
    });

    test('tracks the visible month while stepping forward and back', () async {
      final details = await savePlan(bookIds: {8});
      final viewModel = newViewModel(details);
      await viewModel.initialize();

      final start = viewModel.visibleMonth;

      await viewModel.showNextMonth();
      expect(viewModel.visibleMonth, DateTime(start.year, start.month + 1));

      await viewModel.showPreviousMonth();
      expect(viewModel.visibleMonth, start);
    });

    test('exposes checked days for the visible month', () async {
      final details = await savePlan(bookIds: {8});
      final viewModel = newViewModel(details);
      await viewModel.initialize();

      expect(viewModel.checkedDays.values, everyElement(isFalse));

      final month = viewModel.visibleMonth;
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

      expect(viewModel.checkedDays, hasLength(daysInMonth));
      expect(viewModel.dayProgress(1), isNotNull);
    });
  });

  group('bookmark', () {
    test('toggles optimistically and persists the new state', () async {
      final details = await savePlan(bookIds: {8});
      final viewModel = newViewModel(details);
      await viewModel.initialize();

      expect(viewModel.isBookmarked, isFalse);

      await viewModel.toggleBookmark();

      expect(viewModel.isBookmarked, isTrue);
      expect(
        (await planService.getReadingPlanById(
          details.readingPlan.id!,
        ))!.readingPlan.isBookmarked,
        isTrue,
      );

      await viewModel.toggleBookmark();

      expect(viewModel.isBookmarked, isFalse);
      expect(
        (await planService.getReadingPlanById(
          details.readingPlan.id!,
        ))!.readingPlan.isBookmarked,
        isFalse,
      );
    });

    test('rolls back the optimistic flip when persistence fails', () async {
      final details = await savePlan(bookIds: {8});
      final failingService = FailingBookmarkPlanService(
        database,
        bibleNavigation,
      );
      final viewModel = newViewModel(details, service: failingService);
      await viewModel.initialize();

      final future = viewModel.toggleBookmark();
      expect(viewModel.isBookmarked, isTrue);

      await future;

      expect(viewModel.isBookmarked, isFalse);
    });
  });

  group('reorder', () {
    test(
      'persists 1-indexed ord values and reloads the resume position after a move',
      () async {
        final plan = await planService.saveReadingPlan(
          planName: 'Exodus First Test',
          collectionId: 1,
          goalType: GoalType.verses,
          goalValue: 10,
          selectedBookIds: {1, 2}, // Genesis (1), Exodus (2)
        );
        final details = (await planService.getReadingPlanById(plan.id!))!;

        final viewModel = newViewModel(details);
        await viewModel.initialize();

        expect(viewModel.resumePosition?.bookId, 1);

        await viewModel.moveBook(1, 0); // Exodus before Genesis

        expect(viewModel.books.map((book) => book.bookId), [2, 1]);
        expect(viewModel.books.map((book) => book.ord), [1, 2]);
        expect(viewModel.resumePosition?.bookId, 2);

        final storedBooks = await database.getReadingPlanBooks(plan.id!);
        expect(storedBooks.map((book) => book.bookId), [2, 1]);
        expect(storedBooks.map((book) => book.ord), [1, 2]);

        final resume = await planService.getResumeReference(plan.id!);
        expect(resume?.bookId, 2);
      },
    );
  });

  group('progressForBook', () {
    test(
      'keys stats by bookId so sparse stats do not index positionally',
      () async {
        final details = await savePlan(bookIds: {63, 64});
        final planId = details.readingPlan.id!;
        await database.markVerseRead(planId, 63, 1, 1);

        final sparseService = SparseStatsPlanService(database, bibleNavigation);
        final viewModel = newViewModel(details, service: sparseService);
        await viewModel.initialize();

        expect(viewModel.bookStats.keys, [63]);
        expect(viewModel.progressForBook(63), closeTo(1 / 13, 1e-9));
        expect(viewModel.progressForBook(64), 0);
        expect(viewModel.isBookComplete(63), isFalse);
      },
    );
  });

  group('estimated completion', () {
    test('projects days and months for a verses goal', () async {
      // Ruth (book 8) has 85 verses in the versification fixture.
      final details = await savePlan(
        bookIds: {8},
        goalType: GoalType.verses,
        goalValue: 10,
      );
      final viewModel = newViewModel(details);
      await viewModel.initialize();

      expect(viewModel.totalVerses, 85);
      expect(viewModel.hasEstimate, isTrue);
      expect(viewModel.estimatedDays, 9); // ceil(85 / 10)
      expect(viewModel.estimatedMonths, closeTo(9 / 30.44, 1e-9));
    });

    test('converts minutes to verses at five verses per minute', () async {
      final details = await savePlan(
        bookIds: {8},
        goalType: GoalType.minutes,
        goalValue: 5,
      );
      final viewModel = newViewModel(details);
      await viewModel.initialize();

      // ceil(85 / (5 minutes * 5 verses/minute)) = ceil(85 / 25) = 4
      expect(viewModel.estimatedDays, 4);
    });
  });

  group('startReadingSession', () {
    test('starts the session for the plan', () async {
      final details = await savePlan(bookIds: {8});
      final planId = details.readingPlan.id!;
      await database.markVerseRead(planId, 8, 1, 1);

      final viewModel = newViewModel(details);
      await viewModel.initialize();

      expect(
        viewModel.resumePosition,
        const Reference(bookId: 8, chapter: 1, verse: 2),
      );

      await viewModel.startReadingSession();

      expect(sessionViewModel.startedPlanIds, [planId]);
    });
  });
}
