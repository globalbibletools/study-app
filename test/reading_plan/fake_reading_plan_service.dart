import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';

class FakeReadingPlanService extends Fake implements ReadingPlanService {
  FakeReadingPlanService([List<ReadingPlanDetails>? plans])
    : plans = plans ?? [];

  List<ReadingPlanDetails> plans;
  List<RsBookStats> bookStats = const [];
  List<DayProgress> monthProgress = const [];
  List<SessionDetails> detailedProgress = const [];
  Reference? resumePosition;

  final monthProgressByMonth = <DateTime, List<DayProgress>>{};
  final requestedMonths = <DateTime>[];
  final detailedProgressDates = <DateTime>[];
  final detailedProgressPlanIds = <int>[];
  final deletedPlanIds = <int>[];
  final bookmarkedValues = <bool>[];
  final reorderedBooks = <List<ReadingPlanBook>>[];

  /// When set, bookmark writes throw this instead of persisting.
  Object? bookmarkError;

  /// When set, reorder writes throw this instead of persisting.
  Object? reorderError;

  /// When true, calls to [getReadingPlansWithProgress] wait until the
  /// corresponding completer in [getRequests] is completed.
  bool queueGetRequests = false;
  final getRequests = <Completer<List<ReadingPlanDetails>>>[];

  /// When true, calls to [getReadingPlanById] wait until the corresponding
  /// completer in [planRequests] is completed.
  bool queuePlanRequests = false;
  final planRequests = <Completer<ReadingPlanDetails?>>[];

  /// When true, calls to [getBooksStats] wait until the corresponding
  /// completer in [statsRequests] is completed.
  bool queueStatsRequests = false;
  final statsRequests = <Completer<List<RsBookStats>>>[];

  /// When true, calls to [getDetailedProgressFor] wait until the corresponding
  /// completer in [detailedProgressRequests] is completed.
  bool queueDetailedProgressRequests = false;
  final detailedProgressRequests = <Completer<List<SessionDetails>>>[];

  /// When set, detailed progress queries throw this instead of returning data.
  Object? detailedProgressError;

  /// When set, deletes wait for this to complete before taking effect.
  Completer<void>? deleteGate;

  ReadingPlanDetails? _detailsFor(int planId) =>
      plans.where((plan) => plan.readingPlan.id == planId).firstOrNull;

  @override
  Future<List<ReadingPlanDetails>> getReadingPlansWithProgress() {
    if (queueGetRequests) {
      final request = Completer<List<ReadingPlanDetails>>();
      getRequests.add(request);
      return request.future;
    }
    return Future.value(List.of(plans));
  }

  @override
  Future<ReadingPlanDetails?> getReadingPlanById(int planId) {
    if (queuePlanRequests) {
      final request = Completer<ReadingPlanDetails?>();
      planRequests.add(request);
      return request.future;
    }
    return Future.value(_detailsFor(planId));
  }

  @override
  Future<List<RsBookStats>> getBooksStats(int readingPlanId) {
    if (queueStatsRequests) {
      final request = Completer<List<RsBookStats>>();
      statsRequests.add(request);
      return request.future;
    }
    return Future.value(List.of(bookStats));
  }

  @override
  Future<List<SessionDetails>> getDetailedProgressFor(
    DateTime date,
    int readingPlanId,
  ) {
    detailedProgressDates.add(date);
    detailedProgressPlanIds.add(readingPlanId);

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
  Future<Reference?> getResumeReference(int planId) async {
    return _detailsFor(planId)?.resumePosition ?? resumePosition;
  }

  @override
  Future<DayProgress> getDayProgress(int readingPlanId, DateTime date) async {
    final progress =
        [
          ...monthProgress,
          for (final month in monthProgressByMonth.values) ...month,
        ].where(
          (progress) =>
              progress.day.year == date.year &&
              progress.day.month == date.month &&
              progress.day.day == date.day,
        );

    return progress.firstOrNull ?? DayProgress.empty(date);
  }

  @override
  Future<List<DayProgress>> getMonthProgress(
    int readingPlanId,
    DateTime month,
  ) async {
    final normalized = DateTime(month.year, month.month);
    requestedMonths.add(normalized);
    return monthProgressByMonth[normalized] ?? monthProgress;
  }

  @override
  Future<ReadingPlan> setReadingPlanBookmark(
    ReadingPlan readingPlan,
    bool isBookmarked,
  ) async {
    final error = bookmarkError;
    if (error != null) throw error;

    bookmarkedValues.add(isBookmarked);
    final updated = readingPlan.copyWith(isBookmarked: isBookmarked);
    _detailsFor(readingPlan.id!)?.readingPlan = updated;
    return updated;
  }

  @override
  Future<void> reorderReadingPlanBooks(
    int readingPlanId,
    List<ReadingPlanBook> books,
  ) async {
    final error = reorderError;
    if (error != null) throw error;

    final ordered = List<ReadingPlanBook>.of(books);
    reorderedBooks.add(ordered);
    final details = _detailsFor(readingPlanId);
    if (details != null) {
      final index = plans.indexWhere(
        (plan) => plan.readingPlan.id == readingPlanId,
      );
      plans[index] = ReadingPlanDetails(details.readingPlan, ordered)
        ..resumePosition = details.resumePosition;
    }
  }

  @override
  Future<void> deleteReadingPlan(int planId) async {
    final gate = deleteGate;
    if (gate != null) await gate.future;

    deletedPlanIds.add(planId);
    plans = plans.where((plan) => plan.readingPlan.id != planId).toList();
  }
}
