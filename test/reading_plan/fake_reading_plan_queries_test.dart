import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';

import 'fake_reading_plan_queries.dart';

void main() {
  test('serves the in-memory read-model surface', () async {
    final day = DateTime(2026, 11, 17);
    final summary = _summary(1, day: day);
    final queries = FakeReadingPlanQueries([summary])
      ..monthProgressByMonth[DateTime(2026, 11)] = {
        17: _dailyProgress(day, verses: 3),
      }
      ..dayActivity = [
        SessionActivity(
          sessionId: 10,
          startTime: DateTime(2026, 11, 17, 9),
          readSeconds: 120,
          verses: 3,
          isManual: false,
          ranges: const [VerseRange(63, 1, 1, 3)],
        ),
      ]
      ..runtimes[10] = SessionRuntime(
        sessionId: 10,
        planId: 1,
        sessionDay: day,
        sessionStartTime: DateTime(2026, 11, 17, 9),
        sessionReadSeconds: 120,
        dayProgress: _dailyProgress(day, verses: 3),
      )
      ..verseReadStates[(10, 63, 1)] = {
        1: const VerseReadState(readCount: 1, readThisSession: true),
      };

    expect((await queries.getPlanConfig(1))!.planName, 'Plan 1');
    expect((await queries.getPlanSummary(1, today: day))!.today.verses, 3);
    expect(await queries.getPlanSummaries(today: day), hasLength(1));
    expect((await queries.getMonthDayProgress(1, DateTime(2026, 11, 1))).keys, [
      17,
    ]);
    expect((await queries.getDayProgress(1, day)).verses, 3);

    final activity = await queries.getDayActivity(1, day);
    expect(activity.sessions.single.ranges.single.toVerse, 3);

    expect((await queries.getSessionRuntime(10))!.sessionReadSeconds, 120);
    expect((await queries.getVerseReadStates(10, 63, 1))[1]!.readCount, 1);
    expect(queries.requestedMonths, [DateTime(2026, 11)]);
    expect(queries.requestedDays, [day]);
    expect(queries.dayActivityDates, [day]);
    expect(queries.dayActivityPlanIds, [1]);
  });

  test('supports queued and failing day activity reads', () async {
    final queries = FakeReadingPlanQueries()..queueDayActivityRequests = true;
    final future = queries.getDayActivity(1, DateTime(2026, 11, 17));
    expect(queries.dayActivityRequests, hasLength(1));

    queries.dayActivityRequests.single.complete(
      DayActivity(day: DateTime(2026, 11, 17), sessions: const []),
    );
    expect((await future).sessions, isEmpty);

    queries
      ..queueDayActivityRequests = false
      ..dayActivityError = StateError('failed');
    await expectLater(
      queries.getDayActivity(1, DateTime(2026, 11, 17)),
      throwsA(isA<StateError>()),
    );
  });
}

ReadingPlanSummary _summary(int planId, {required DateTime day}) {
  return ReadingPlanSummary(
    config: ReadingPlanConfig(
      planId: planId,
      planName: 'Plan $planId',
      isBookmarked: false,
      createdAt: DateTime(2026, 1, 1),
      dailyGoal: const DailyGoal(GoalType.verses, 5),
      bookIds: const [63],
    ),
    progress: ReadingPlanProgress(
      planId: planId,
      bookProgress: const {
        63: BookProgress(bookId: 63, totalVerses: 13, versesRead: 1),
      },
      resumePosition: const Reference(bookId: 63, chapter: 1, verse: 2),
    ),
    today: DailyProgress.empty(day),
  );
}

DailyProgress _dailyProgress(DateTime day, {required int verses}) {
  return DailyProgress(
    day: day,
    seconds: 120,
    verses: verses,
    goalReached: false,
    goal: const DailyGoal(GoalType.verses, 5),
  );
}
