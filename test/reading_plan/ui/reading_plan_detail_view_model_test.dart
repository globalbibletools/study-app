import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/ui/reading_plan_detail_view_model.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart';

import '../fake_reading_plan_queries.dart';
import '../fake_reading_plan_service.dart';
import '../fake_reading_session_view_model.dart';

void main() {
  late FakeReadingSessionViewModel sessionViewModel;
  late FakeReadingPlanQueries queries;

  setUp(() {
    sessionViewModel = FakeReadingSessionViewModel();
    queries = FakeReadingPlanQueries();
  });

  Future<ReadingPlanDetailViewModel> newViewModel(
    FakeReadingPlanService service, {
    int planId = 7,
  }) async {
    final viewModel = await ReadingPlanDetailViewModel.create(
      planId: planId,
      queries: queries,
      planService: service,
      sessionViewModel: sessionViewModel,
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  group('initialization', () {
    test(
      'loads plan details, stats, and today\'s and month progress',
      () async {
        final today = dateOnly(DateTime.now());
        final service =
            FakeReadingPlanService([
                planDetails(
                  bookIds: const [63, 64],
                  resumePosition: const Reference(
                    bookId: 63,
                    chapter: 1,
                    verse: 1,
                  ),
                ),
              ])
              ..bookStats = [
                bookStats(63, totalVerses: 13, versesRead: 13),
                bookStats(64, totalVerses: 15, versesRead: 0),
              ];
        queries.monthProgressByMonth[monthStart(today)] = {
          today.day: dailyProgress(
            today,
            minutes: 10,
            verses: 13,
            goalReached: true,
          ),
        };
        final viewModel = await newViewModel(service);
        expect(viewModel.planId, 7);
        expect(viewModel.planName, 'Ruth Plan');
        expect(viewModel.isBookmarked, isFalse);
        expect(viewModel.books.map((book) => book.bookId), [63, 64]);
        expect(viewModel.bookStats.keys, [63, 64]);
        expect(viewModel.totalVerses, 28);
        expect(viewModel.versesRead, 13);
        expect(viewModel.booksRead, 1);
        expect(viewModel.hasStarted, isTrue);
        expect(viewModel.overallProgress, closeTo(13 / 28, 1e-9));
        expect(viewModel.todaysProgress.verses, 13);
        expect(viewModel.todaysProgress.minutes, 10);
        expect(viewModel.calendarProgress[today.day], 1);
        expect(viewModel.dayProgress(today.day)!.day, today);
      },
    );

    test('throws when the plan is missing', () async {
      final service = FakeReadingPlanService();

      await expectLater(newViewModel(service), throwsA(isA<StateError>()));
    });

    test('refresh propagates a load error and recovers', () async {
      final service = FakeReadingPlanService([planDetails()]);
      final viewModel = await newViewModel(service);

      service.plans = [];
      await expectLater(viewModel.refresh(), throwsA(isA<StateError>()));

      service.plans = [planDetails(name: 'Recovered Plan')];
      await viewModel.refresh();

      expect(viewModel.planName, 'Recovered Plan');
    });

    test('a newer refresh cancels the in-flight one and wins', () async {
      final details = planDetails(bookIds: const [8]);
      final service = FakeReadingPlanService([details]);
      final viewModel = await newViewModel(service);

      service.queuePlanRequests = true;
      service.queueStatsRequests = true;

      final first = viewModel.refresh();
      final second = viewModel.refresh();

      expect(service.planRequests, hasLength(2));

      service.planRequests[0].complete(details);
      await expectLater(first, throwsA(isA<CancelledError>()));

      service.planRequests[1].complete(details);
      await pumpEventQueue();
      expect(service.statsRequests, hasLength(1));

      service.statsRequests.single.complete([
        bookStats(8, totalVerses: 85, versesRead: 85),
      ]);
      await second;
      expect(viewModel.versesRead, 85);
      expect(viewModel.bookStats[8]!.isComplete, isTrue);
      expect(viewModel.hasStarted, isTrue);
    });
  });

  group('dispose', () {
    test(
      'does not notify after dispose while a refresh is in flight',
      () async {
        final details = planDetails(bookIds: const [8]);
        final service = FakeReadingPlanService([details]);
        final viewModel = await ReadingPlanDetailViewModel.create(
          planId: 7,
          queries: queries,
          planService: service,
          sessionViewModel: sessionViewModel,
        );
        service.queuePlanRequests = true;

        var notifications = 0;
        viewModel.addListener(() => notifications++);

        final future = viewModel.refresh();
        expect(service.planRequests, hasLength(1));
        final notificationsBeforeDispose = notifications;

        viewModel.dispose();
        service.planRequests.single.complete(details);
        await expectLater(future, throwsA(isA<CancelledError>()));

        expect(notifications, notificationsBeforeDispose);
      },
    );
  });

  group('bookmarks', () {
    test('toggles on and off and persists each new state', () async {
      final service = FakeReadingPlanService([planDetails()]);
      final viewModel = await newViewModel(service);

      expect(viewModel.isBookmarked, isFalse);

      await viewModel.toggleBookmark();

      expect(viewModel.isBookmarked, isTrue);
      expect(service.bookmarkedValues, [true]);

      await viewModel.toggleBookmark();

      expect(viewModel.isBookmarked, isFalse);
      expect(service.bookmarkedValues, [true, false]);
    });

    test('keeps the old state when persistence fails', () async {
      final service = FakeReadingPlanService([planDetails()])
        ..bookmarkError = StateError('bookmark write failed');
      final viewModel = await newViewModel(service);

      await expectLater(viewModel.toggleBookmark(), throwsA(isA<StateError>()));

      expect(viewModel.isBookmarked, isFalse);
    });
  });

  group('progress', () {
    test('aggregates only the books in the plan', () async {
      final service =
          FakeReadingPlanService([
              planDetails(bookIds: const [63, 64]),
            ])
            ..bookStats = [
              bookStats(63, totalVerses: 13, versesRead: 13),
              bookStats(64, totalVerses: 15, versesRead: 5),
              bookStats(99, totalVerses: 100, versesRead: 100),
            ];
      final viewModel = await newViewModel(service);

      expect(viewModel.totalVerses, 28);
      expect(viewModel.versesRead, 18);
      expect(viewModel.booksRead, 1);
      expect(viewModel.overallProgress, closeTo(18 / 28, 1e-9));
      expect(viewModel.progressForBook(63), 1);
      expect(viewModel.progressForBook(64), closeTo(5 / 15, 1e-9));
      expect(viewModel.progressForBook(999), 0);
    });

    test('keys stats by book id when the stats are sparse', () async {
      final service = FakeReadingPlanService([
        planDetails(bookIds: const [63, 64]),
      ])..bookStats = [bookStats(63, totalVerses: 13, versesRead: 1)];
      final viewModel = await newViewModel(service);

      expect(viewModel.bookStats.keys, [63]);
      expect(viewModel.progressForBook(63), closeTo(1 / 13, 1e-9));
      expect(viewModel.progressForBook(64), 0);
      expect(viewModel.totalVerses, 13);
      expect(viewModel.versesRead, 1);
    });

    test('uses verses toward a verse goal', () async {
      final today = dateOnly(DateTime.now());
      final service = FakeReadingPlanService([
        planDetails(goalType: GoalType.verses, goalValue: 10),
      ]);
      queries.monthProgressByMonth[monthStart(today)] = {
        today.day: dailyProgress(today, minutes: 7, verses: 3),
      };
      final viewModel = await newViewModel(service);

      expect(viewModel.goalType, GoalType.verses);
      expect(viewModel.goalValue, 10);
      expect(viewModel.todaysProgress.verses, 3);
      expect(viewModel.todaysProgress.minutes, 7);
      expect(viewModel.todaysGoalProgress, closeTo(0.3, 1e-9));
    });

    test('uses minutes toward a minutes goal', () async {
      final today = dateOnly(DateTime.now());
      final service = FakeReadingPlanService([
        planDetails(goalType: GoalType.minutes, goalValue: 20),
      ]);
      queries.monthProgressByMonth[monthStart(today)] = {
        today.day: dailyProgress(today, minutes: 7, verses: 3),
      };
      final viewModel = await newViewModel(service);

      expect(viewModel.goalType, GoalType.minutes);
      expect(viewModel.goalValue, 20);
      expect(viewModel.todaysProgress.minutes, 7);
      expect(viewModel.todaysGoalProgress, closeTo(0.35, 1e-9));
    });

    test('reports no goal progress when the goal is zero', () async {
      final today = dateOnly(DateTime.now());
      final service = FakeReadingPlanService([
        planDetails(goalType: GoalType.verses, goalValue: 0),
      ]);
      queries.monthProgressByMonth[monthStart(today)] = {
        today.day: dailyProgress(today, minutes: 7, verses: 3),
      };
      final viewModel = await newViewModel(service);

      expect(viewModel.todaysGoalProgress, 0);
    });
  });

  group('plan estimates', () {
    test('projects days for a verse goal', () async {
      final service = FakeReadingPlanService([
        planDetails(bookIds: const [8], goalValue: 10),
      ])..bookStats = [bookStats(8, totalVerses: 85, versesRead: 0)];
      final viewModel = await newViewModel(service);

      expect(viewModel.totalVerses, 85);
      expect(viewModel.hasEstimate, isTrue);
      expect(viewModel.estimatedDays, 9);
    });

    test('converts minutes to verses for a minutes goal', () async {
      final service = FakeReadingPlanService([
        planDetails(
          bookIds: const [8],
          goalType: GoalType.minutes,
          goalValue: 5,
        ),
      ])..bookStats = [bookStats(8, totalVerses: 85, versesRead: 0)];
      final viewModel = await newViewModel(service);

      // ceil(85 / (5 minutes * 5 verses/minute)) = 4
      expect(viewModel.estimatedDays, 4);
    });

    test('has no estimate when the plan is complete', () async {
      final service = FakeReadingPlanService([
        planDetails(bookIds: const [8], goalValue: 10),
      ])..bookStats = [bookStats(8, totalVerses: 85, versesRead: 85)];
      final viewModel = await newViewModel(service);

      expect(viewModel.hasEstimate, isFalse);
      expect(viewModel.estimatedDays, 0);
    });

    test('has no estimate when the goal cannot make progress', () async {
      final service = FakeReadingPlanService([
        planDetails(bookIds: const [8], goalValue: 0),
      ])..bookStats = [bookStats(8, totalVerses: 85, versesRead: 0)];
      final viewModel = await newViewModel(service);

      expect(viewModel.hasEstimate, isFalse);
      expect(viewModel.estimatedDays, 0);
    });
  });

  group('reading reference', () {
    test('uses the resume position loaded with the plan', () async {
      final service = FakeReadingPlanService([
        planDetails(
          bookIds: const [8, 20],
          resumePosition: const Reference(bookId: 20, chapter: 3, verse: 4),
        ),
      ]);
      final viewModel = await newViewModel(service);

      expect(
        viewModel.readingReference,
        const Reference(bookId: 20, chapter: 3, verse: 4),
      );
    });

    test('falls back to the first book without a resume position', () async {
      final service = FakeReadingPlanService([
        planDetails(bookIds: const [8, 20]),
      ]);
      final viewModel = await newViewModel(service);

      expect(
        viewModel.readingReference,
        const Reference(bookId: 8, chapter: 1, verse: 1),
      );
    });

    test('falls back to Genesis when the plan has no books', () async {
      final service = FakeReadingPlanService([planDetails(bookIds: const [])]);
      final viewModel = await newViewModel(service);

      expect(
        viewModel.readingReference,
        const Reference(bookId: 1, chapter: 1, verse: 1),
      );
    });
  });

  group('session start', () {
    test('starts a session for the plan', () async {
      final service = FakeReadingPlanService([planDetails()]);
      final viewModel = await newViewModel(service);

      await viewModel.startReadingSession();

      expect(sessionViewModel.startedPlanIds, [7]);
    });
  });

  group('month progress', () {
    test('exposes calendar days for the visible month', () async {
      final month = monthStart(DateTime.now());
      final service = FakeReadingPlanService([planDetails()]);
      queries.monthProgressByMonth[month] = {
        1: dailyProgress(
          DateTime(month.year, month.month, 1),
          minutes: 10,
          verses: 10,
          goalReached: true,
        ),
        3: dailyProgress(DateTime(month.year, month.month, 3)),
      };
      final viewModel = await newViewModel(service);

      expect(viewModel.visibleMonth, month);
      final progress = viewModel.calendarProgress;
      expect(progress, hasLength(2));
      expect(progress[1], 1);
      expect(progress.containsKey(2), isFalse);
      expect(progress[3], 0);
      expect(viewModel.dayProgress(1)!.goalReached, isTrue);
      expect(viewModel.dayProgress(2), isNull);
    });

    test('omits empty days and exposes clamped fractions', () async {
      final month = monthStart(DateTime.now());
      final service = FakeReadingPlanService([planDetails()]);
      queries.monthProgressByMonth[month] = {
        1: dailyProgress(
          DateTime(month.year, month.month, 1),
          minutes: 10,
          verses: 4,
        ),
        3: dailyProgress(DateTime(month.year, month.month, 3)),
        4: dailyProgress(
          DateTime(month.year, month.month, 4),
          minutes: 10,
          verses: 10,
          goalReached: true,
        ),
        5: dailyProgress(
          DateTime(month.year, month.month, 5),
          minutes: 10,
          verses: 20,
        ),
      };
      final viewModel = await newViewModel(service);

      final progress = viewModel.calendarProgress;
      expect(progress, hasLength(4));
      expect(progress[1], closeTo(0.4, 1e-9));
      expect(progress.containsKey(2), isFalse);
      expect(progress[3], 0);
      expect(progress[4], 1);
      expect(progress[5], 1);
    });

    test('uses minutes for per-day progress toward a minutes goal', () async {
      final month = monthStart(DateTime.now());
      final service = FakeReadingPlanService([
        planDetails(goalType: GoalType.minutes, goalValue: 20),
      ]);
      queries.monthProgressByMonth[month] = {
        1: dailyProgress(
          DateTime(month.year, month.month, 1),
          minutes: 7,
          verses: 3,
        ),
      };
      final viewModel = await newViewModel(service);

      expect(viewModel.calendarProgress[1], closeTo(0.35, 1e-9));
    });

    test('uses the stored goal snapshot for calendar fractions', () async {
      final month = monthStart(DateTime.now());
      final service = FakeReadingPlanService([
        planDetails(goalType: GoalType.verses, goalValue: 20),
      ]);
      queries.monthProgressByMonth[month] = {
        1: dailyProgress(
          DateTime(month.year, month.month, 1),
          minutes: 10,
          verses: 10,
          goal: const DailyGoal(GoalType.verses, 10),
        ),
      };
      final viewModel = await newViewModel(service);

      expect(viewModel.calendarProgress[1], 1);
    });

    test('reads today separately from the visible month', () async {
      final month = monthStart(DateTime.now());
      final today = dateOnly(DateTime.now());
      final service = FakeReadingPlanService([planDetails()]);
      queries.monthProgressByMonth[month] = {
        today.day: dailyProgress(today, minutes: 3, verses: 1),
      };
      queries.dayProgressByDay[today] = dailyProgress(
        today,
        minutes: 9,
        verses: 5,
      );
      final viewModel = await newViewModel(service);

      expect(viewModel.todaysProgress.verses, 5);
      expect(viewModel.todaysProgress.minutes, 9);
      expect(viewModel.calendarProgress[today.day], closeTo(0.1, 1e-9));
    });

    test(
      'navigating to the next month requests and replaces its data',
      () async {
        final current = monthStart(DateTime.now());
        final next = DateTime(current.year, current.month + 1);
        final service = FakeReadingPlanService([planDetails()]);
        queries.monthProgressByMonth[current] = const {};
        queries.monthProgressByMonth[next] = {
          1: dailyProgress(
            DateTime(next.year, next.month, 1),
            minutes: 5,
            verses: 5,
            goalReached: true,
          ),
        };
        final viewModel = await newViewModel(service);

        await viewModel.showNextMonth();

        expect(viewModel.visibleMonth, next);
        expect(queries.requestedMonths.last, next);
        expect(viewModel.calendarProgress[1], 1);
        expect(
          viewModel.dayProgress(1)!.day,
          DateTime(next.year, next.month, 1),
        );
      },
    );

    test(
      'refresh keeps today\'s progress while viewing another month',
      () async {
        final current = monthStart(DateTime.now());
        final next = DateTime(current.year, current.month + 1);
        final today = dateOnly(DateTime.now());
        final service = FakeReadingPlanService([planDetails()]);
        queries.dayProgressByDay[today] = dailyProgress(
          today,
          minutes: 7,
          verses: 3,
        );
        queries.monthProgressByMonth[next] = const {};
        final viewModel = await newViewModel(service);

        await viewModel.showNextMonth();
        queries.dayProgressByDay[today] = dailyProgress(
          today,
          minutes: 9,
          verses: 5,
        );
        await viewModel.refresh();

        expect(viewModel.visibleMonth, next);
        expect(viewModel.todaysProgress.verses, 5);
        expect(viewModel.todaysProgress.minutes, 9);
        expect(queries.requestedDays, [today, today]);
      },
    );

    test('navigating back restores the previous month', () async {
      final current = monthStart(DateTime.now());
      final next = DateTime(current.year, current.month + 1);
      final service = FakeReadingPlanService([planDetails()]);
      queries.monthProgressByMonth[current] = const {};
      queries.monthProgressByMonth[next] = const {};
      final viewModel = await newViewModel(service);

      await viewModel.showNextMonth();
      await viewModel.showPreviousMonth();

      expect(viewModel.visibleMonth, current);
      expect(queries.requestedMonths.last, current);
    });
  });
}

ReadingPlanDetails planDetails({
  int id = 7,
  String name = 'Ruth Plan',
  GoalType goalType = GoalType.verses,
  int goalValue = 10,
  List<int> bookIds = const [8],
  Reference? resumePosition,
  bool isBookmarked = false,
}) {
  final details = ReadingPlanDetails(
    ReadingPlan(
      id: id,
      planName: name,
      createdAt: DateTime(2026, 1, 1),
      goalType: goalType.name,
      goalValue: goalValue,
      isBookmarked: isBookmarked,
    ),
    [
      for (var i = 0; i < bookIds.length; i++)
        ReadingPlanBook(readingPlanId: id, bookId: bookIds[i], ord: i + 1),
    ],
  );
  details.resumePosition = resumePosition;
  return details;
}

RsBookStats bookStats(
  int bookId, {
  required int totalVerses,
  required int versesRead,
}) {
  return RsBookStats(
    bookId: bookId,
    totalVerses: totalVerses,
    versesRead: versesRead,
    lastRead: null,
  );
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime monthStart(DateTime value) => DateTime(value.year, value.month);

DailyProgress dailyProgress(
  DateTime day, {
  int minutes = 0,
  int verses = 0,
  bool goalReached = false,
  DailyGoal? goal,
}) {
  return DailyProgress(
    day: day,
    seconds: minutes * 60,
    verses: verses,
    goalReached: goalReached,
    goal: goal,
  );
}
