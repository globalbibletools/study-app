import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/ui/day_activity_log_view_model.dart';

import '../fake_reading_plan_queries.dart';
import '../fake_reading_plan_service.dart';

void main() {
  late FakeReadingPlanService planService;
  late FakeReadingPlanQueries queries;
  late DateTime date;

  const planId = 1;

  setUp(() {
    queries = FakeReadingPlanQueries();
    planService = FakeReadingPlanService()..queries = queries;
    date = DateTime(2026, 11, 17);
  });

  Future<DayActivityLogViewModel> newViewModel() async {
    final viewModel = await DayActivityLogViewModel.create(
      readingPlanId: planId,
      date: date,
      queries: queries,
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
      queries.dayActivity = sessions;

      final viewModel = await newViewModel();

      expect(viewModel.readingPlanId, planId);
      expect(viewModel.date, date);
      expect(viewModel.sessions, sessions);
      expect(viewModel.totalMinutes, 15);
      expect(viewModel.totalVerses, 5);
      expect(viewModel.minutesFor(viewModel.sessions.first), 10);
      expect(viewModel.minutesFor(viewModel.sessions.last), 5);
      expect(queries.dayActivityDates, [date]);
      expect(queries.dayActivityPlanIds, [planId]);
    });

    test('rounds session and total minutes to one decimal place', () async {
      queries.dayActivity = [
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

    test('returns references already folded and sorted by the query', () async {
      queries.dayActivity = [
        session(
          ranges: const [
            VerseRange(63, 1, 1, 2),
            VerseRange(63, 1, 4, 4),
            VerseRange(63, 2, 1, 1),
            VerseRange(64, 1, 1, 1),
          ],
        ),
      ];

      final viewModel = await newViewModel();

      final progress = viewModel.referencesFor(viewModel.sessions.single);
      expect(progress.map((entry) => entry.bookId), [63, 63, 63, 64]);
      expect(progress.map((entry) => entry.chapter), [1, 1, 2, 1]);
      expect(progress.map((entry) => entry.fromVerse), [1, 4, 1, 1]);
    });

    test('refresh replaces sessions with the latest query data', () async {
      queries.dayActivity = [session(verses: 1)];
      final viewModel = await newViewModel();
      expect(viewModel.sessions, hasLength(1));

      queries.dayActivity = [
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
      queries.dayActivity = [session(id: 1, readSeconds: 60, verses: 1)];
      final viewModel = await newViewModel();

      await viewModel.addManualSession(minutes: 5.5, verses: 2);

      final call = planService.addedManualSessions.single;
      expect(call.readingPlanId, planId);
      expect(call.date, date);
      expect(call.minutes, 5.5);
      expect(call.verses, 2);
      expect(viewModel.sessions, hasLength(2));
      expect(viewModel.sessions.last.isManual, isTrue);
      expect(viewModel.sessions.last.readSeconds, 330);
      expect(viewModel.totalMinutes, 6.5);
      expect(viewModel.totalVerses, 3);
    });

    test('deletes a manual session and refreshes the session list', () async {
      queries.dayActivity = [
        session(id: 1, readSeconds: 60, verses: 1),
        session(id: 2, isManual: true, readSeconds: 300, verses: 2),
      ];
      final viewModel = await newViewModel();

      await viewModel.deleteManualSession(2);

      expect(planService.deletedManualSessionIds, [2]);
      expect(viewModel.sessions.map((entry) => entry.sessionId), [1]);
      expect(viewModel.totalMinutes, 1);
      expect(viewModel.totalVerses, 1);
    });

    test('propagates a load error from create', () async {
      queries.dayActivityError = StateError('day activity query failed');

      await expectLater(newViewModel(), throwsA(isA<StateError>()));
    });

    test('refresh can recover after a load error', () async {
      queries.dayActivity = [session(verses: 1)];
      final viewModel = await newViewModel();

      queries.dayActivityError = StateError('day activity query failed');
      await expectLater(viewModel.refresh(), throwsA(isA<StateError>()));

      queries.dayActivityError = null;
      queries.dayActivity = [session(readSeconds: 120, verses: 1)];
      await viewModel.refresh();

      expect(viewModel.sessions, hasLength(1));
      expect(viewModel.totalMinutes, 2);
      expect(viewModel.totalVerses, 1);
    });
  });

  group('concurrency', () {
    test('a newer refresh cancels the in-flight one and wins', () async {
      queries.dayActivity = [session(verses: 1)];
      final viewModel = await newViewModel();
      queries.queueDayActivityRequests = true;

      final first = viewModel.refresh();
      final second = viewModel.refresh();

      expect(queries.dayActivityRequests, hasLength(2));

      queries.dayActivityRequests[0].complete(
        DayActivity(day: date, sessions: [session(verses: 1)]),
      );
      await expectLater(first, throwsA(isA<CancelledError>()));

      queries.dayActivityRequests[1].complete(
        DayActivity(day: date, sessions: [session(verses: 2)]),
      );
      await second;

      expect(viewModel.sessions.single.verses, 2);
    });

    test(
      'does not notify after dispose while a refresh is in flight',
      () async {
        queries.dayActivity = [session()];
        final viewModel = await DayActivityLogViewModel.create(
          readingPlanId: planId,
          date: date,
          queries: queries,
          planService: planService,
        );
        queries.queueDayActivityRequests = true;
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        final future = viewModel.refresh();
        expect(queries.dayActivityRequests, hasLength(1));
        final notificationsBeforeDispose = notifications;

        viewModel.dispose();
        queries.dayActivityRequests.single.complete(
          DayActivity(day: date, sessions: [session()]),
        );
        await expectLater(future, throwsA(isA<CancelledError>()));

        expect(notifications, notificationsBeforeDispose);
      },
    );
  });
}

SessionActivity session({
  int? id,
  int readSeconds = 0,
  int verses = 0,
  DateTime? startTime,
  bool isManual = false,
  List<VerseRange> ranges = const [],
}) {
  return SessionActivity(
    sessionId: id ?? 1,
    startTime: startTime ?? DateTime(2026, 11, 17, 9),
    readSeconds: readSeconds,
    verses: verses,
    isManual: isManual,
    ranges: ranges,
  );
}
