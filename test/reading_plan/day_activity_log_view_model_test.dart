import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/reading_plan/day_activity_log_view_model.dart';
import 'package:gbt/reading_plan/rs_model.dart';

import 'fake_reading_plan_service.dart';

void main() {
  late FakeReadingPlanService planService;
  late DateTime date;

  const planId = 1;

  setUp(() {
    planService = FakeReadingPlanService();
    date = DateTime(2026, 11, 17);
  });

  DayActivityLogViewModel newViewModel() {
    final viewModel = DayActivityLogViewModel.withDependencies(
      readingPlanId: planId,
      date: date,
      planService: planService,
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  group('initialization', () {
    test('loads sessions and derives totals for the requested day', () async {
      final sessions = [
        session(readSeconds: 600, verses: 3),
        session(
          readSeconds: 300,
          verses: 2,
          startTime: DateTime(2026, 11, 17, 14),
        ),
      ];
      planService.detailedProgress = sessions;

      final viewModel = newViewModel();
      expect(viewModel.sessions, isEmpty);

      await viewModel.initialize();

      expect(viewModel.readingPlanId, planId);
      expect(viewModel.date, date);
      expect(viewModel.sessions, sessions);
      expect(viewModel.totalMinutes, 15);
      expect(viewModel.totalVerses, 5);
      expect(viewModel.minutesFor(viewModel.sessions.first), 10);
      expect(viewModel.minutesFor(viewModel.sessions.last), 5);
      expect(planService.detailedProgressDates, [date]);
      expect(planService.detailedProgressPlanIds, [planId]);
    });

    test('rounds session and total minutes to one decimal place', () async {
      planService.detailedProgress = [
        session(readSeconds: 90, verses: 1),
        session(
          readSeconds: 100,
          verses: 1,
          startTime: DateTime(2026, 11, 17, 14),
        ),
      ];

      final viewModel = newViewModel();
      await viewModel.initialize();

      expect(viewModel.minutesFor(viewModel.sessions.first), 1.5);
      expect(viewModel.minutesFor(viewModel.sessions.last), 1.7);
      expect(viewModel.totalMinutes, 3.2);
    });

    test('sorts references by book, chapter, and verse', () async {
      planService.detailedProgress = [
        session(
          progress: [
            DetailedProgess(64, 1, 1, 1),
            DetailedProgess(63, 2, 1, 1),
            DetailedProgess(63, 1, 4, 4),
            DetailedProgess(63, 1, 1, 2),
          ],
        ),
      ];

      final viewModel = newViewModel();
      await viewModel.initialize();

      final progress = viewModel.referencesFor(viewModel.sessions.single);
      expect(progress.map((entry) => entry.bookId), [63, 63, 63, 64]);
      expect(progress.map((entry) => entry.chapter), [1, 1, 2, 1]);
      expect(progress.map((entry) => entry.fromVerse), [1, 4, 1, 1]);
    });

    test('refresh replaces sessions with the latest service data', () async {
      planService.detailedProgress = [session(verses: 1)];
      final viewModel = newViewModel();
      await viewModel.initialize();
      expect(viewModel.sessions, hasLength(1));

      planService.detailedProgress = [
        session(verses: 2),
        session(
          readSeconds: 60,
          verses: 3,
          startTime: DateTime(2026, 11, 17, 14),
        ),
      ];
      await viewModel.refresh();

      expect(viewModel.sessions, hasLength(2));
      expect(viewModel.totalVerses, 5);
    });

    test('propagates a load error from initialize', () async {
      planService.detailedProgressError = StateError(
        'detailed progress query failed',
      );
      final viewModel = newViewModel();

      await expectLater(viewModel.initialize(), throwsA(isA<StateError>()));

      expect(viewModel.sessions, isEmpty);
    });

    test('refresh can recover after an initialize error', () async {
      planService.detailedProgressError = StateError(
        'detailed progress query failed',
      );
      final viewModel = newViewModel();
      await expectLater(viewModel.initialize(), throwsA(isA<StateError>()));

      planService.detailedProgressError = null;
      planService.detailedProgress = [session(readSeconds: 120, verses: 1)];
      await viewModel.refresh();

      expect(viewModel.sessions, hasLength(1));
      expect(viewModel.totalMinutes, 2);
      expect(viewModel.totalVerses, 1);
    });
  });

  group('concurrency', () {
    test('a newer refresh cancels the in-flight one and wins', () async {
      planService
        ..queueDetailedProgressRequests = true
        ..detailedProgress = [session(verses: 1)];
      final viewModel = newViewModel();

      final first = viewModel.refresh();
      final second = viewModel.refresh();

      expect(planService.detailedProgressRequests, hasLength(2));

      planService.detailedProgressRequests[0].complete([session(verses: 1)]);
      await expectLater(first, throwsA(isA<CancelledError>()));

      planService.detailedProgressRequests[1].complete([session(verses: 2)]);
      await second;

      expect(viewModel.sessions.single.rsSession.verses, 2);
    });

    test(
      'does not notify after dispose while a refresh is in flight',
      () async {
        planService.queueDetailedProgressRequests = true;
        final viewModel = DayActivityLogViewModel.withDependencies(
          readingPlanId: planId,
          date: date,
          planService: planService,
        );
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        final future = viewModel.refresh();
        expect(planService.detailedProgressRequests, hasLength(1));
        final notificationsBeforeDispose = notifications;

        viewModel.dispose();
        planService.detailedProgressRequests.single.complete([session()]);
        await expectLater(future, throwsA(isA<CancelledError>()));

        expect(notifications, notificationsBeforeDispose);
      },
    );
  });
}

SessionDetails session({
  int readSeconds = 0,
  int verses = 0,
  DateTime? startTime,
  List<DetailedProgess> progress = const [],
}) {
  final day = DateTime(2026, 11, 17);
  return SessionDetails(
    RsSession(
      rsDate: day,
      startTime: startTime ?? DateTime(2026, 11, 17, 9),
      readSeconds: readSeconds,
      verses: verses,
      readingPlanId: 1,
    ),
    progress,
  );
}
