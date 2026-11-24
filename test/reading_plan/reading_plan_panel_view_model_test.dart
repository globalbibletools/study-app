import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_panel_view_model.dart';

import 'fake_reading_plan_read_models.dart';
import 'fake_reading_session_view_model.dart';
import 'reading_plan_fixtures.dart';

void main() {
  late FakeReadingPlanReadModels readModels;
  late FakeReadingSessionViewModel sessionViewModel;
  late ReadingPlanPanelViewModel viewModel;

  Future<ReadingPlanPanelViewModel> newViewModel({
    FakeReadingPlanReadModels? models,
  }) {
    return ReadingPlanPanelViewModel.create(
      readModels: models ?? readModels,
      sessionViewModel: sessionViewModel,
    );
  }

  setUp(() async {
    readModels = FakeReadingPlanReadModels();
    sessionViewModel = FakeReadingSessionViewModel();
    viewModel = await newViewModel();
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('initialization', () {
    test('create loads plans with progress fields populated', () async {
      final today = DateTime(2026, 11, 23);
      readModels.plans = [
        planSummary(
          name: 'Ruth',
          totalVerses: 85,
          today: DayProgress.minutes(today, 0, 3, false),
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
    });

    test(
      'refresh replaces the plan list with the latest database state',
      () async {
        expect(viewModel.plans, isEmpty);

        readModels.plans = [planSummary(name: 'First')];
        await viewModel.refresh();

        expect(viewModel.plans, hasLength(1));
        expect(viewModel.plans.single.planName, 'First');
      },
    );

    test('a newer refresh cancels the in-flight one and wins', () async {
      final models = FakeReadingPlanReadModels();
      final localViewModel = await newViewModel(models: models);
      addTearDown(localViewModel.dispose);
      models.queueGetRequests = true;

      final first = localViewModel.refresh();
      final second = localViewModel.refresh();

      expect(models.getRequests, hasLength(2));

      models.getRequests[0].complete([planSummary(name: 'Stale')]);
      await expectLater(first, throwsA(isA<CancelledError>()));

      models.getRequests[1].complete([planSummary(name: 'Fresh')]);
      await second;

      expect(localViewModel.plans.single.planName, 'Fresh');
    });
  });

  group('startReadingSession', () {
    test('starts a session for the selected plan', () async {
      readModels.plans = [planSummary(name: 'Ruth', id: 7)];
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
        final models = FakeReadingPlanReadModels();
        final localViewModel = await newViewModel(models: models);
        models.queueGetRequests = true;
        var notifications = 0;
        localViewModel.addListener(() => notifications++);

        final future = localViewModel.refresh();
        final notificationsBeforeDispose = notifications;

        localViewModel.dispose();
        models.getRequests.single.complete([planSummary(name: 'Late')]);
        await expectLater(future, throwsA(isA<CancelledError>()));

        expect(notifications, notificationsBeforeDispose);
      },
    );
  });
}
