import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';

class FakeReadingPlanReadModels extends Fake implements ReadingPlanReadModels {
  FakeReadingPlanReadModels([List<ReadingPlanSummary>? plans])
    : plans = plans ?? [];

  List<ReadingPlanSummary> plans;
  List<BookProgress> bookStats = const [];
  List<DayProgress> monthProgress = const [];
  List<SessionDetails> detailedProgress = const [];
  Reference? resumePosition;

  final monthProgressByMonth = <DateTime, List<DayProgress>>{};
  final requestedMonths = <DateTime>[];
  final detailedProgressDates = <DateTime>[];
  final detailedProgressPlanIds = <int>[];

  int planConfigCalls = 0;
  int summaryCalls = 0;
  final runtimes = <int, ReadingSessionRuntime>{};
  final verseReadStates = <(int, int, int), Map<int, VerseReadState>>{};

  bool queueGetRequests = false;
  final getRequests = <Completer<List<ReadingPlanSummary>>>[];

  bool queueSummaryRequests = false;
  final summaryRequests = <Completer<ReadingPlanSummary?>>[];

  bool queueDetailedProgressRequests = false;
  final detailedProgressRequests = <Completer<List<SessionDetails>>>[];

  Object? detailedProgressError;

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
        for (final book in summary.books)
          book.bookId:
              stats[book.bookId] ??
              BookProgress(bookId: book.bookId, totalVerses: 0, versesRead: 0),
      },
      resumePosition: resumePosition ?? summary.progress.resumePosition,
    );

    return ReadingPlanSummary(
      config: summary.config,
      progress: progress,
      today: summary.today.hasSummary
          ? summary.today
          : _todayFromProgress(today ?? DateTime.now()) ?? summary.today,
    );
  }

  DayProgress? _todayFromProgress(DateTime date) {
    final progress = [
      ...monthProgress,
      for (final month in monthProgressByMonth.values) ...month,
    ];
    return progress
        .where(
          (entry) =>
              entry.day.year == date.year &&
              entry.day.month == date.month &&
              entry.day.day == date.day,
        )
        .firstOrNull;
  }

  @override
  Future<ReadingPlanConfig?> getPlanConfig(int planId) async {
    planConfigCalls++;
    return _summaryFor(planId)?.config;
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
    return Future.value(List.of(plans));
  }

  @override
  Future<List<DayProgress>> getMonthProgress(int planId, DateTime month) async {
    final normalized = DateTime(month.year, month.month);
    requestedMonths.add(normalized);
    return monthProgressByMonth[normalized] ?? monthProgress;
  }

  @override
  Future<List<SessionDetails>> getDayActivity(int planId, DateTime date) {
    detailedProgressDates.add(date);
    detailedProgressPlanIds.add(planId);

    if (queueDetailedProgressRequests) {
      final request = Completer<List<SessionDetails>>();
      detailedProgressRequests.add(request);
      return request.future;
    }

    final error = detailedProgressError;
    if (error != null) return Future.error(error);
    return Future.value(List.of(detailedProgress));
  }

  @override
  Future<ReadingSessionRuntime?> getSessionRuntime(int sessionId) async {
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
