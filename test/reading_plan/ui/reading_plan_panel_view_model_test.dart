import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/ui/reading_plan_panel_view_model.dart';

import '../fake_reading_plan_queries.dart';
import '../fake_reading_session_view_model.dart';

void main() {
  late FakeReadingPlanQueries queries;
  late FakeReadingSessionViewModel sessionViewModel;
  late ReadingPlanPanelViewModel viewModel;

  Future<ReadingPlanPanelViewModel> newViewModel({
    FakeReadingPlanQueries? querySource,
  }) {
    return ReadingPlanPanelViewModel.create(
      queries: querySource ?? queries,
      sessionViewModel: sessionViewModel,
    );
  }

  setUp(() async {
    queries = FakeReadingPlanQueries();
    sessionViewModel = FakeReadingSessionViewModel();
    viewModel = await newViewModel();
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('initialization', () {
    test(
      'create loads plan summaries with progress fields populated',
      () async {
        final today = DateTime(2026, 11, 23);
        queries.plans = [
          planSummary(
            'Ruth',
            totalVerses: 85,
            today: DailyProgress(
              day: today,
              seconds: 0,
              verses: 3,
              goalReached: false,
              goal: null,
            ),
            resumePosition: const Reference(bookId: 8, chapter: 1, verse: 1),
          ),
        ];
        final localViewModel = await newViewModel();
        addTearDown(localViewModel.dispose);

        expect(localViewModel.plans, hasLength(1));

        final plan = localViewModel.plans.single;
        expect(plan.planName, 'Ruth');
        expect(plan.totalVerses, 85);
        expect(plan.versesRead, 0);
        expect(plan.today.verses, 3);
        expect(plan.today.goalReached, isFalse);
        expect(
          plan.resumePosition,
          const Reference(bookId: 8, chapter: 1, verse: 1),
        );
      },
    );

    test(
      'refresh replaces the plan list with the latest database state',
      () async {
        expect(viewModel.plans, isEmpty);

        queries.plans = [planSummary('First')];
        await viewModel.refresh();

        expect(viewModel.plans, hasLength(1));
        expect(viewModel.plans.single.planName, 'First');
      },
    );

    test('a newer refresh cancels the in-flight one and wins', () async {
      final querySource = FakeReadingPlanQueries();
      final localViewModel = await newViewModel(querySource: querySource);
      addTearDown(localViewModel.dispose);
      querySource.queueGetRequests = true;

      final first = localViewModel.refresh();
      final second = localViewModel.refresh();

      expect(querySource.getRequests, hasLength(2));

      querySource.getRequests[0].complete([planSummary('Stale')]);
      await expectLater(first, throwsA(isA<CancelledError>()));

      querySource.getRequests[1].complete([planSummary('Fresh')]);
      await second;

      expect(localViewModel.plans.single.planName, 'Fresh');
    });
  });

  group('startReadingSession', () {
    test('starts a session for the selected plan', () async {
      queries.plans = [planSummary('Ruth', id: 7)];
      final localViewModel = await newViewModel();
      addTearDown(localViewModel.dispose);
      final plan = localViewModel.plans.single;

      await localViewModel.startReadingSession(plan);

      expect(sessionViewModel.startedPlanIds, [7]);
    });
  });

  group('dispose', () {
    test(
      'does not notify after dispose while a refresh is in flight',
      () async {
        final querySource = FakeReadingPlanQueries();
        final localViewModel = await newViewModel(querySource: querySource);
        querySource.queueGetRequests = true;
        var notifications = 0;
        localViewModel.addListener(() => notifications++);

        final future = localViewModel.refresh();
        final notificationsBeforeDispose = notifications;

        localViewModel.dispose();
        querySource.getRequests.single.complete([planSummary('Late')]);
        await expectLater(future, throwsA(isA<CancelledError>()));

        expect(notifications, notificationsBeforeDispose);
      },
    );
  });
}

ReadingPlanSummary planSummary(
  String name, {
  int id = 1,
  int totalVerses = 0,
  int versesRead = 0,
  DailyProgress? today,
  Reference? resumePosition,
}) {
  return ReadingPlanSummary(
    config: ReadingPlanConfig(
      planId: id,
      planName: name,
      isBookmarked: false,
      createdAt: DateTime.now(),
      dailyGoal: const DailyGoal(GoalType.verses, 10),
      bookIds: const [8],
    ),
    progress: ReadingPlanProgress(
      planId: id,
      bookProgress: {
        8: BookProgress(
          bookId: 8,
          totalVerses: totalVerses,
          versesRead: versesRead,
        ),
      },
      resumePosition: resumePosition,
    ),
    today: today ?? DailyProgress.empty(DateTime.now()),
  );
}
