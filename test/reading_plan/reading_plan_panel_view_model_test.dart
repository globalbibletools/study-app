import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_panel_view_model.dart';
import 'package:gbt/reading_plan/rs_model.dart';

import 'fake_reading_plan_service.dart';
import 'fake_reading_session_view_model.dart';

void main() {
  late FakeReadingPlanService planService;
  late FakeReadingSessionViewModel sessionViewModel;
  late ReadingPlanPanelViewModel viewModel;

  Future<ReadingPlanPanelViewModel> newViewModel({
    FakeReadingPlanService? service,
  }) {
    return ReadingPlanPanelViewModel.create(
      planService: service ?? planService,
      sessionViewModel: sessionViewModel,
    );
  }

  setUp(() async {
    planService = FakeReadingPlanService();
    sessionViewModel = FakeReadingSessionViewModel();
    viewModel = await newViewModel();
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('initialization', () {
    test('create loads plans with progress fields populated', () async {
      final today = DateTime(2026, 11, 23);
      planService.plans = [
        planDetails(
          'Ruth',
          totalVerses: 85,
          todayProgress: DayProgress(today, 0, 3, false),
          resumePosition: const Reference(bookId: 8, chapter: 1, verse: 1),
        ),
      ];
      final localViewModel = await newViewModel();
      addTearDown(localViewModel.dispose);

      expect(localViewModel.plans, hasLength(1));

      final plan = localViewModel.plans.single;
      expect(plan.readingPlan.planName, 'Ruth');
      expect(plan.totalVerses, 85);
      expect(plan.versesRead, 0);
      expect(plan.todayProgress?.verses, 3);
      expect(plan.todayProgress?.goalReached, isFalse);
      expect(
        plan.resumePosition,
        const Reference(bookId: 8, chapter: 1, verse: 1),
      );
    });

    test(
      'refresh replaces the plan list with the latest database state',
      () async {
        expect(viewModel.plans, isEmpty);

        planService.plans = [planDetails('First')];
        await viewModel.refresh();

        expect(viewModel.plans, hasLength(1));
        expect(viewModel.plans.single.readingPlan.planName, 'First');
      },
    );

    test('a newer refresh cancels the in-flight one and wins', () async {
      final service = FakeReadingPlanService();
      final localViewModel = await newViewModel(service: service);
      addTearDown(localViewModel.dispose);
      service.queueGetRequests = true;

      final first = localViewModel.refresh();
      final second = localViewModel.refresh();

      expect(service.getRequests, hasLength(2));

      service.getRequests[0].complete([planDetails('Stale')]);
      await expectLater(first, throwsA(isA<CancelledError>()));

      service.getRequests[1].complete([planDetails('Fresh')]);
      await second;

      expect(localViewModel.plans.single.readingPlan.planName, 'Fresh');
    });
  });

  group('deletePlan', () {
    test(
      'removes the plan after it is persisted and keeps other plans',
      () async {
        planService.plans = [
          planDetails('Keep', id: 1),
          planDetails('Doomed', id: 2),
        ];
        final localViewModel = await newViewModel();
        addTearDown(localViewModel.dispose);

        final gate = Completer<void>();
        planService.deleteGate = gate;

        final future = localViewModel.deletePlan(2);

        // Removal happens after the delete completes.
        expect(
          localViewModel.plans.map((plan) => plan.readingPlan.id).toSet(),
          {1, 2},
        );
        expect(planService.deletedPlanIds, isEmpty);

        gate.complete();
        await future;

        expect(localViewModel.plans.map((plan) => plan.readingPlan.id), [1]);
        expect(planService.deletedPlanIds, [2]);
      },
    );
  });

  group('startReadingSession', () {
    test('starts a session for the selected plan', () async {
      planService.plans = [planDetails('Ruth', id: 7)];
      final localViewModel = await newViewModel();
      addTearDown(localViewModel.dispose);
      final plan = localViewModel.plans.single;

      await localViewModel.startReadingSession(plan);

      expect(sessionViewModel.startedPlanIds, [7]);
    });

    test('does not start a session when the plan has no id', () async {
      await viewModel.startReadingSession(planDetails('Unsaved', id: null));

      expect(sessionViewModel.startedPlanIds, isEmpty);
    });
  });

  group('dispose', () {
    test(
      'does not notify after dispose while a refresh is in flight',
      () async {
        final service = FakeReadingPlanService();
        final localViewModel = await newViewModel(service: service);
        service.queueGetRequests = true;
        var notifications = 0;
        localViewModel.addListener(() => notifications++);

        final future = localViewModel.refresh();
        final notificationsBeforeDispose = notifications;

        localViewModel.dispose();
        service.getRequests.single.complete([planDetails('Late')]);
        await expectLater(future, throwsA(isA<CancelledError>()));

        expect(notifications, notificationsBeforeDispose);
      },
    );
  });
}

ReadingPlanDetails planDetails(
  String name, {
  int? id = 1,
  int totalVerses = 0,
  int versesRead = 0,
  DayProgress? todayProgress,
  Reference? resumePosition,
}) {
  final details = ReadingPlanDetails(
    ReadingPlan(
      id: id,
      planName: name,
      createdAt: DateTime.now(),
      collectionId: 1,
      goalType: GoalType.verses.name,
      goalValue: 10,
      isBookmarked: false,
    ),
    const [],
  );
  details.totalVerses = totalVerses;
  details.versesRead = versesRead;
  details.todayProgress = todayProgress;
  details.resumePosition = resumePosition;
  return details;
}
