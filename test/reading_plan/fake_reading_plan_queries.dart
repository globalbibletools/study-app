import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';

class FakeReadingPlanQueries extends Fake implements ReadingPlanQueries {
  FakeReadingPlanQueries([List<ReadingPlanSummary>? plans])
    : plans = plans ?? [];

  List<ReadingPlanSummary> plans;
  final configs = <int, ReadingPlanConfig>{};
  List<BookProgress> bookStats = const [];
  List<SessionActivity> dayActivity = [];
  Reference? resumePosition;

  final monthProgressByMonth = <DateTime, Map<int, DailyProgress>>{};
  final dayProgressByDay = <DateTime, DailyProgress>{};
  final requestedMonths = <DateTime>[];
  final requestedDays = <DateTime>[];
  final dayActivityDates = <DateTime>[];
  final dayActivityPlanIds = <int>[];

  int planConfigCalls = 0;
  int summaryCalls = 0;
  final runtimes = <int, SessionRuntime>{};
  final verseReadStates = <(int, int, int), Map<int, VerseReadState>>{};

  bool queueGetRequests = false;
  final getRequests = <Completer<List<ReadingPlanSummary>>>[];

  bool queueSummaryRequests = false;
  final summaryRequests = <Completer<ReadingPlanSummary?>>[];

  bool queueDayActivityRequests = false;
  final dayActivityRequests = <Completer<DayActivity>>[];

  Object? dayActivityError;

  ReadingPlanSummary? _summaryFor(int planId) =>
      plans.where((plan) => plan.planId == planId).firstOrNull;

  ReadingPlanSummary _withOverrides(
    ReadingPlanSummary summary, {
    DateTime? today,
  }) {
    final stats = bookStats.isEmpty
        ? summary.bookProgress
        : {for (final stat in bookStats) stat.bookId: stat};
    final progress = ReadingPlanProgress(
      planId: summary.planId,
      bookProgress: {
        for (final bookId in summary.bookIds)
          bookId:
              stats[bookId] ??
              BookProgress(bookId: bookId, totalVerses: 0, versesRead: 0),
      },
      resumePosition: resumePosition ?? summary.progress.resumePosition,
    );

    return ReadingPlanSummary(
      config: summary.config,
      progress: progress,
      today: summary.today.hasSummary
          ? summary.today
          : _progressForDay(today ?? DateTime.now()) ?? summary.today,
    );
  }

  DailyProgress? _progressForDay(DateTime date) {
    return monthProgressByMonth[DateTime(date.year, date.month)]?[date.day];
  }

  @override
  Future<ReadingPlanConfig?> getPlanConfig(int planId) async {
    planConfigCalls++;
    return configs[planId] ?? _summaryFor(planId)?.config;
  }

  @override
  Future<ReadingPlanSummary?> getPlanSummary(int planId, {DateTime? today}) {
    summaryCalls++;
    if (queueSummaryRequests) {
      final request = Completer<ReadingPlanSummary?>();
      summaryRequests.add(request);
      return request.future;
    }
    final summary = _summaryFor(planId);
    return Future.value(
      summary == null ? null : _withOverrides(summary, today: today),
    );
  }

  @override
  Future<List<ReadingPlanSummary>> getPlanSummaries({DateTime? today}) {
    if (queueGetRequests) {
      final request = Completer<List<ReadingPlanSummary>>();
      getRequests.add(request);
      return request.future;
    }
    return Future.value([
      for (final summary in plans) _withOverrides(summary, today: today),
    ]);
  }

  @override
  Future<DailyProgress> getDayProgress(int planId, DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    requestedDays.add(normalized);
    return dayProgressByDay[normalized] ??
        monthProgressByMonth[DateTime(day.year, day.month)]?[day.day] ??
        DailyProgress.empty(normalized);
  }

  @override
  Future<Map<int, DailyProgress>> getMonthDayProgress(
    int planId,
    DateTime month,
  ) async {
    final normalized = DateTime(month.year, month.month);
    requestedMonths.add(normalized);
    return Map.of(monthProgressByMonth[normalized] ?? const {});
  }

  @override
  Future<DayActivity> getDayActivity(int planId, DateTime date) {
    dayActivityDates.add(date);
    dayActivityPlanIds.add(planId);

    if (queueDayActivityRequests) {
      final request = Completer<DayActivity>();
      dayActivityRequests.add(request);
      return request.future;
    }

    final error = dayActivityError;
    if (error != null) return Future.error(error);
    return Future.value(DayActivity(day: date, sessions: List.of(dayActivity)));
  }

  @override
  Future<SessionRuntime?> getSessionRuntime(int sessionId) async {
    return runtimes[sessionId];
  }

  @override
  Future<Map<int, VerseReadState>> getVerseReadStates(
    int sessionId,
    int bookId,
    int chapter,
  ) async {
    return verseReadStates[(sessionId, bookId, chapter)] ?? const {};
  }
}
