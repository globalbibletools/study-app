import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/reading_plan/reading_plan_detail_view_model.dart';
import 'package:gbt/ui/home/reading_plan/reading_session_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/bible_navigation_fixture.dart';

class FakeReadingSessionViewModel extends Fake
    implements ReadingSessionViewModel {
  final startedPlanIds = <int>[];

  @override
  Future<void> startSession(int planId) async {
    startedPlanIds.add(planId);
  }
}

class FakeHomeManager extends Fake implements HomeManager {
  Reference? jumpedTo;

  @override
  void jumpToReference(Reference reference) {
    jumpedTo = reference;
  }
}

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
  late FakeHomeManager homeManager;

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
    homeManager = FakeHomeManager();

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
      bibleNavigation: bibleNavigation,
      homeManager: homeManager,
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

  ReadingPlanDetails unsavedDetails({
    Reference? resumePosition,
    List<int> bookIds = const [8, 32],
  }) {
    final details = ReadingPlanDetails(
      ReadingPlan(
        id: 1,
        planName: 'Unsaved Seed',
        createdAt: DateTime.now(),
        collectionId: 1,
        goalType: GoalType.verses.name,
        goalValue: 10,
        isBookmarked: false,
      ),
      [
        for (int i = 0; i < bookIds.length; i++)
          ReadingPlanBook(readingPlanId: 1, bookId: bookIds[i], ord: i + 1),
      ],
    );
    details.resumePosition = resumePosition;
    return details;
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
        await viewModel.ready;

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

    test('deduplicates concurrent refresh calls', () async {
      final details = await savePlan(bookIds: {8});
      final viewModel = newViewModel(details);

      final first = viewModel.refresh();
      final second = viewModel.refresh();

      expect(identical(first, second), isTrue);
      await first;
    });

    test('loadMonthData replaces the calendar month data', () async {
      final details = await savePlan(bookIds: {8});
      final viewModel = newViewModel(details);
      await viewModel.ready;

      await viewModel.loadMonthData(DateTime(2026, 11, 1));

      expect(viewModel.monthProgress.value, hasLength(30));
      expect(viewModel.monthProgress.value.first.day, DateTime(2026, 11, 1));
    });
  });

  group('bookmark', () {
    test('toggles optimistically and persists the new state', () async {
      final details = await savePlan(bookIds: {8});
      final viewModel = newViewModel(details);
      await viewModel.ready;

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
      await viewModel.ready;

      final future = viewModel.toggleBookmark();
      expect(viewModel.isBookmarked, isTrue);

      await future;

      expect(viewModel.isBookmarked, isFalse);
    });
  });

  group('reorder', () {
    test(
      'persists 1-indexed ord values and reloads the resume position on exit',
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
        await viewModel.ready;

        expect(viewModel.resumeTarget.bookId, 1);

        await viewModel.toggleReorderMode();
        expect(viewModel.isReorderMode, isTrue);

        viewModel.moveBook(1, 0); // Exodus before Genesis

        await viewModel.toggleReorderMode();
        expect(viewModel.isReorderMode, isFalse);

        expect(viewModel.books.map((book) => book.bookId), [2, 1]);
        expect(viewModel.books.map((book) => book.ord), [1, 2]);
        expect(viewModel.resumeTarget.bookId, 2);

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
        await viewModel.ready;

        expect(viewModel.bookStats.keys, [63]);
        expect(viewModel.progressForBook(63), closeTo(1 / 13, 1e-9));
        expect(viewModel.progressForBook(64), 0);
        expect(viewModel.isBookComplete(63), isFalse);
      },
    );
  });

  group('resumeTarget', () {
    test('uses the resume position when present', () {
      const resumePosition = Reference(bookId: 8, chapter: 2, verse: 3);
      final viewModel = newViewModel(
        unsavedDetails(resumePosition: resumePosition),
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.resumeTarget, resumePosition);
    });

    test('falls back to the first book at 1:1:1 when resume is null', () {
      final viewModel = newViewModel(unsavedDetails(bookIds: const [32, 8]));
      addTearDown(viewModel.dispose);

      expect(
        viewModel.resumeTarget,
        const Reference(bookId: 32, chapter: 1, verse: 1),
      );
    });

    test('falls back to Bible start when the plan has no books', () {
      final viewModel = newViewModel(unsavedDetails(bookIds: const []));
      addTearDown(viewModel.dispose);

      expect(
        viewModel.resumeTarget,
        const Reference(bookId: 1, chapter: 1, verse: 1),
      );
    });
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
      await viewModel.ready;

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
      await viewModel.ready;

      // ceil(85 / (5 minutes * 5 verses/minute)) = ceil(85 / 25) = 4
      expect(viewModel.estimatedDays, 4);
    });
  });

  group('startReadingSession', () {
    test('starts the session and navigates to the resume target', () async {
      final details = await savePlan(bookIds: {8});
      final planId = details.readingPlan.id!;
      await database.markVerseRead(planId, 8, 1, 1);

      final viewModel = newViewModel(details);
      await viewModel.ready;

      const expectedResume = Reference(bookId: 8, chapter: 1, verse: 2);
      expect(viewModel.resumeTarget, expectedResume);

      await viewModel.startReadingSession();

      expect(sessionViewModel.startedPlanIds, [planId]);
      expect(homeManager.jumpedTo, expectedResume);
    });
  });
}
