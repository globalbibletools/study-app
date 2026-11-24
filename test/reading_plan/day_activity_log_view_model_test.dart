import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/reading_plan/day_activity_log_view_model.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart';

import 'fake_reading_plan_service.dart';

void main() {
  late FakeReadingPlanService planService;
  late DateTime date;

  const planId = 1;

  setUp(() {
    planService = FakeReadingPlanService();
    date = DateTime(2026, 11, 17);
  });

  Future<DayActivityLogViewModel> newViewModel() async {
    final viewModel = await DayActivityLogViewModel.create(
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

      final viewModel = await newViewModel();

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

      final viewModel = await newViewModel();

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

      final viewModel = await newViewModel();

      final progress = viewModel.referencesFor(viewModel.sessions.single);
      expect(progress.map((entry) => entry.bookId), [63, 63, 63, 64]);
      expect(progress.map((entry) => entry.chapter), [1, 1, 2, 1]);
      expect(progress.map((entry) => entry.fromVerse), [1, 4, 1, 1]);
    });

    test('refresh replaces sessions with the latest service data', () async {
      planService.detailedProgress = [session(verses: 1)];
      final viewModel = await newViewModel();
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

    test('adds a manual session and refreshes the session list', () async {
      planService.detailedProgress = [
        session(id: 1, readSeconds: 60, verses: 1),
      ];
      final viewModel = await newViewModel();

      await viewModel.addManualSession(minutes: 5.5, verses: 2);

      final call = planService.addedManualSessions.single;
      expect(call.readingPlanId, planId);
      expect(call.date, date);
      expect(call.minutes, 5.5);
      expect(call.verses, 2);
      expect(viewModel.sessions, hasLength(2));
      expect(viewModel.sessions.last.rsSession.isManual, isTrue);
      expect(viewModel.sessions.last.rsSession.readSeconds, 330);
      expect(viewModel.totalMinutes, 6.5);
      expect(viewModel.totalVerses, 3);
    });

    test('deletes a manual session and refreshes the session list', () async {
      planService.detailedProgress = [
        session(id: 1, readSeconds: 60, verses: 1),
        session(id: 2, isManual: true, readSeconds: 300, verses: 2),
      ];
      final viewModel = await newViewModel();

      await viewModel.deleteManualSession(2);

      expect(planService.deletedManualSessionIds, [2]);
      expect(viewModel.sessions.map((entry) => entry.rsSession.id), [1]);
      expect(viewModel.totalMinutes, 1);
      expect(viewModel.totalVerses, 1);
    });

    test('propagates a load error from create', () async {
      planService.detailedProgressError = StateError(
        'detailed progress query failed',
      );

      await expectLater(newViewModel(), throwsA(isA<StateError>()));
    });

    test('refresh can recover after a load error', () async {
      planService.detailedProgress = [session(verses: 1)];
      final viewModel = await newViewModel();

      planService.detailedProgressError = StateError(
        'detailed progress query failed',
      );
      await expectLater(viewModel.refresh(), throwsA(isA<StateError>()));

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
      planService.detailedProgress = [session(verses: 1)];
      final viewModel = await newViewModel();
      planService.queueDetailedProgressRequests = true;

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
        planService.detailedProgress = [session()];
        final viewModel = await DayActivityLogViewModel.create(
          readingPlanId: planId,
          date: date,
          planService: planService,
        );
        planService.queueDetailedProgressRequests = true;
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
  int? id,
  int readSeconds = 0,
  int verses = 0,
  DateTime? startTime,
  bool isManual = false,
  List<DetailedProgess> progress = const [],
}) {
  final day = DateTime(2026, 11, 17);
  return SessionDetails(
    RsSession(
      id: id,
      rsDate: day,
      startTime: startTime ?? DateTime(2026, 11, 17, 9),
      readSeconds: readSeconds,
      verses: verses,
      readingPlanId: 1,
      isManual: isManual,
    ),
    progress,
  );
}
