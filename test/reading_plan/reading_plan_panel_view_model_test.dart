import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/reading_plan/reading_plan_panel_view_model.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';

class FakeHomeManager extends Fake implements HomeManager {
  final jumpedReferences = <Reference>[];

  @override
  void jumpToReference(Reference reference) {
    jumpedReferences.add(reference);
  }
}

/// Integration tests for [ReadingPlanPanelViewModel] running against a real
/// in-memory SQLite database, the real [ReadingPlanService] and
/// [ReadingSessionService], and a [BibleNavigation] backed by the
/// versification fixture.
///
/// Everything is injected directly, except that [ReadingSessionService]
/// resolves [BibleNavigation] through the service locator internally. Tests
/// that would require modifying injected collaborators (e.g. to manufacture a
/// failing delete) are intentionally omitted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late ReadingSessionViewModel sessionViewModel;
  late FakeHomeManager homeManager;
  late ReadingPlanPanelViewModel viewModel;

  ReadingPlanPanelViewModel newViewModel() {
    return ReadingPlanPanelViewModel.withDependencies(
      planService: planService,
      sessionViewModel: sessionViewModel,
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

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final bibleNavigation = createTestBibleNavigation();
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
    getIt.registerSingleton<BibleNavigation>(bibleNavigation);

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
    sessionViewModel = ReadingSessionViewModel.withService(
      ReadingSessionService.withDatabase(database),
    );
    homeManager = FakeHomeManager();
    viewModel = newViewModel();

    // The schema ships with a default "Whole Bible" plan (id 1). Remove it so
    // each test starts from a clean slate.
    for (final plan in await planService.getReadingPlans()) {
      await planService.deleteReadingPlan(plan.readingPlan.id!);
    }
  });

  tearDown(() async {
    await sessionViewModel.endSession();
    sessionViewModel.dispose();
    viewModel.dispose();
    database.dispose();
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
  });

  group('initialization', () {
    test('ready loads plans with progress fields populated', () async {
      await savePlan(name: 'Ruth', bookIds: {8}); // Ruth has 85 verses.

      await viewModel.ready;

      expect(viewModel.plans, hasLength(1));

      final plan = viewModel.plans.single;
      expect(plan.readingPlan.planName, 'Ruth');
      expect(plan.totalVerses, 85);
      expect(plan.versesRead, 0);
      expect(
        plan.resumePosition,
        const Reference(bookId: 8, chapter: 1, verse: 1),
      );
      expect(viewModel.isRefreshing, isFalse);
    });

    test(
      'refresh replaces the plan list with the latest database state',
      () async {
        await viewModel.refresh();
        expect(viewModel.plans, isEmpty);

        await savePlan(name: 'First', bookIds: {1});
        await viewModel.refresh();

        expect(viewModel.plans, hasLength(1));
        expect(viewModel.plans.single.readingPlan.planName, 'First');
      },
    );

    test('concurrent refreshes share one in-flight future', () async {
      await savePlan(bookIds: {1});

      final refreshingStates = <bool>[];
      viewModel.addListener(() {
        refreshingStates.add(viewModel.isRefreshing);
      });

      final first = viewModel.refresh();
      final second = viewModel.refresh();

      expect(identical(first, second), isTrue);
      expect(viewModel.isRefreshing, isTrue);

      await first;

      expect(viewModel.isRefreshing, isFalse);
      expect(refreshingStates, [true, false]);
    });
  });

  group('edit mode', () {
    test('toggleEditMode flips edit mode and notifies each change', () {
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.toggleEditMode();

      expect(viewModel.isEditing, isTrue);
      expect(notifications, 1);

      viewModel.toggleEditMode();

      expect(viewModel.isEditing, isFalse);
      expect(notifications, 2);
    });

    test(
      'exitEditMode turns edit mode off and is a no-op when already off',
      () {
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        viewModel.exitEditMode();

        expect(viewModel.isEditing, isFalse);
        expect(notifications, 0);

        viewModel.toggleEditMode();
        viewModel.exitEditMode();

        expect(viewModel.isEditing, isFalse);
        expect(notifications, 2);
      },
    );
  });

  group('deletePlan', () {
    test('is a no-op for an unsaved plan', () async {
      final unsaved = ReadingPlanDetails(
        ReadingPlan(
          planName: 'Unsaved',
          createdAt: DateTime.now(),
          collectionId: 1,
          goalType: GoalType.verses.name,
          goalValue: 10,
          isBookmarked: false,
        ),
        [],
      );
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.deletePlan(unsaved);

      expect(viewModel.plans, isEmpty);
      expect(notifications, 0);
    });

    test(
      'removes the plan immediately, persists it, and keeps other plans',
      () async {
        await savePlan(name: 'Keep', bookIds: {1});
        await savePlan(name: 'Doomed', bookIds: {2});
        await viewModel.refresh();

        final keepId = viewModel.plans
            .firstWhere((plan) => plan.readingPlan.planName == 'Keep')
            .readingPlan
            .id;
        final doomed = viewModel.plans.firstWhere(
          (plan) => plan.readingPlan.planName == 'Doomed',
        );
        final doomedId = doomed.readingPlan.id;

        final future = viewModel.deletePlan(doomed);

        // Optimistic removal happens before the database call is awaited.
        expect(viewModel.plans.map((plan) => plan.readingPlan.id), [keepId]);

        await future;

        expect(viewModel.plans.map((plan) => plan.readingPlan.id), [keepId]);
        expect(await planService.getReadingPlanById(doomedId!), isNull);
        expect(
          (await planService.getReadingPlans()).map(
            (plan) => plan.readingPlan.id,
          ),
          [keepId],
        );
      },
    );
  });

  group('startReadingSession', () {
    test('starts the session and jumps to the plan resume position', () async {
      await savePlan(bookIds: {8});
      await viewModel.refresh();
      final plan = viewModel.plans.single;

      expect(plan.resumePosition, isNotNull);

      await viewModel.startReadingSession(plan);

      expect(sessionViewModel.hasActiveSession, isTrue);
      expect(homeManager.jumpedReferences, [plan.resumePosition]);
    });

    test(
      'falls back to the first book at 1:1 when resume position is null',
      () async {
        await savePlan(bookIds: {8, 32});
        await viewModel.refresh();
        final plan = viewModel.plans.single..resumePosition = null;

        await viewModel.startReadingSession(plan);

        expect(sessionViewModel.hasActiveSession, isTrue);
        expect(homeManager.jumpedReferences, [
          const Reference(bookId: 8, chapter: 1, verse: 1),
        ]);
      },
    );
  });

  group('resumeTargetFor', () {
    ReadingPlanDetails detailsWith({Reference? resumePosition}) {
      final details = ReadingPlanDetails(
        ReadingPlan(
          planName: 'Test Plan',
          createdAt: DateTime.now(),
          collectionId: 1,
          goalType: GoalType.verses.name,
          goalValue: 10,
          isBookmarked: false,
        ),
        [
          ReadingPlanBook(readingPlanId: 0, bookId: 8, ord: 1),
          ReadingPlanBook(readingPlanId: 0, bookId: 32, ord: 2),
        ],
      );
      details.resumePosition = resumePosition;
      return details;
    }

    test('uses the plan resume position when present', () {
      const resumePosition = Reference(bookId: 8, chapter: 2, verse: 3);

      expect(
        viewModel.resumeTargetFor(detailsWith(resumePosition: resumePosition)),
        resumePosition,
      );
    });

    test(
      'falls back to the first book at 1:1 when resume position is null',
      () {
        expect(
          viewModel.resumeTargetFor(detailsWith()),
          const Reference(bookId: 8, chapter: 1, verse: 1),
        );
      },
    );
  });

  group('dispose', () {
    test(
      'does not notify after dispose while a refresh is in flight',
      () async {
        final localViewModel = newViewModel();
        var notifications = 0;
        localViewModel.addListener(() => notifications++);

        final future = localViewModel.refresh();
        expect(localViewModel.isRefreshing, isTrue);
        final notificationsBeforeDispose = notifications;

        localViewModel.dispose();
        await future;

        expect(notifications, notificationsBeforeDispose);
      },
    );
  });
}
