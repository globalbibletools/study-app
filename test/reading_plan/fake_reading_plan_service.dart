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
  final saveCalls = <SaveReadingPlanCall>[];
  final savedPlans = <ReadingPlan>[];

  /// When set, bookmark writes throw this instead of persisting.
  Object? bookmarkError;

  /// When set, reorder writes throw this instead of persisting.
  Object? reorderError;

  /// When set, saves throw this instead of persisting.
  Object? saveError;

  /// When true, calls to [saveReadingPlan] wait until the corresponding
  /// request in [saveRequests] is completed.
  bool queueSaveRequests = false;
  final saveRequests = <SaveReadingPlanRequest>[];

  /// When set, saves wait for this to complete before taking effect.
  Completer<void>? saveGate;

  /// When set, deletes throw this instead of persisting.
  Object? deleteError;

  /// When true, calls to [deleteReadingPlan] wait until the corresponding
  /// completer in [deleteRequests] is completed.
  bool queueDeleteRequests = false;
  final deleteRequests = <Completer<void>>[];

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
  Future<ReadingPlan> saveReadingPlan({
    ReadingPlanDetails? existingPlanDetails,
    required String planName,
    required int collectionId,
    required GoalType goalType,
    required int goalValue,
    required Set<int> selectedBookIds,
    List<int>? orderedBookIds,
  }) async {
    final call = SaveReadingPlanCall(
      existingPlanDetails: existingPlanDetails,
      planName: planName,
      collectionId: collectionId,
      goalType: goalType,
      goalValue: goalValue,
      selectedBookIds: Set.of(selectedBookIds),
      orderedBookIds: orderedBookIds == null ? null : List.of(orderedBookIds),
    );
    saveCalls.add(call);

    final error = saveError;
    if (error != null) throw error;

    final gate = saveGate;
    if (gate != null) await gate.future;

    final plan = _planFor(call);
    if (queueSaveRequests) {
      final request = SaveReadingPlanRequest(plan);
      saveRequests.add(request);
      final queuedPlan = await request.future;
      _storeSavedPlan(call, queuedPlan);
      return queuedPlan;
    }

    _storeSavedPlan(call, plan);
    return plan;
  }

  ReadingPlan _planFor(SaveReadingPlanCall call) {
    final existing = call.existingPlanDetails?.readingPlan;
    final plan = ReadingPlan(
      id: existing?.id ?? _nextPlanId++,
      planName: call.planName,
      createdAt: existing?.createdAt ?? DateTime.now(),
      lastRead: existing?.lastRead,
      collectionId: call.collectionId,
      goalType: call.goalType.name,
      goalValue: call.goalValue,
      isBookmarked: existing?.isBookmarked ?? false,
    );
    savedPlans.add(plan);
    return plan;
  }

  void _storeSavedPlan(SaveReadingPlanCall call, ReadingPlan plan) {
    final orderedBookIds =
        call.orderedBookIds ?? (call.selectedBookIds.toList()..sort());
    final details = ReadingPlanDetails(plan, [
      for (var i = 0; i < orderedBookIds.length; i++)
        ReadingPlanBook(
          readingPlanId: plan.id!,
          bookId: orderedBookIds[i],
          ord: i + 1,
        ),
    ]);

    final index = plans.indexWhere(
      (existing) => existing.readingPlan.id == plan.id,
    );
    if (index == -1) {
      plans.add(details);
    } else {
      plans[index] = details;
    }
  }

  int _nextPlanId = 100;

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
    final error = deleteError;
    if (error != null) throw error;

    final gate = deleteGate;
    if (gate != null) await gate.future;

    if (queueDeleteRequests) {
      final request = Completer<void>();
      deleteRequests.add(request);
      await request.future;
    }

    deletedPlanIds.add(planId);
    plans = plans.where((plan) => plan.readingPlan.id != planId).toList();
  }
}

class SaveReadingPlanCall {
  const SaveReadingPlanCall({
    required this.existingPlanDetails,
    required this.planName,
    required this.collectionId,
    required this.goalType,
    required this.goalValue,
    required this.selectedBookIds,
    required this.orderedBookIds,
  });

  final ReadingPlanDetails? existingPlanDetails;
  final String planName;
  final int collectionId;
  final GoalType goalType;
  final int goalValue;
  final Set<int> selectedBookIds;
  final List<int>? orderedBookIds;
}

class SaveReadingPlanRequest {
  SaveReadingPlanRequest(this.plan);

  final ReadingPlan plan;
  final _completer = Completer<ReadingPlan>();

  Future<ReadingPlan> get future => _completer.future;

  void complete([ReadingPlan? plan]) => _completer.complete(plan ?? this.plan);

  void completeError(Object error) => _completer.completeError(error);
}
