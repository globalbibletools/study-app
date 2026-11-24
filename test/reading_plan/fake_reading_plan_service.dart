import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart'
    as repo;
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart';

import 'fake_reading_plan_queries.dart';

class FakeReadingPlanService extends Fake implements ReadingPlanService {
  FakeReadingPlanService([List<ReadingPlanDetails>? plans])
    : plans = plans ?? [];

  List<ReadingPlanDetails> plans;
  List<RsBookStats> bookStats = const [];
  List<DayProgress> monthProgress = const [];
  Reference? resumePosition;

  /// When set, commands that change day activity update this fake too.
  FakeReadingPlanQueries? queries;

  final monthProgressByMonth = <DateTime, List<DayProgress>>{};
  final requestedMonths = <DateTime>[];
  final addedManualSessions = <AddManualSessionCall>[];
  final deletedManualSessionIds = <int>[];
  final deletedPlanIds = <int>[];
  final bookmarkedValues = <bool>[];
  final reorderedBooks = <List<int>>[];
  final saveCalls = <SaveReadingPlanCall>[];
  final savedPlans = <repo.ReadingPlan>[];

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

  /// When true, calls to [getReadingPlanById] wait until the corresponding
  /// completer in [planRequests] is completed.
  bool queuePlanRequests = false;
  final planRequests = <Completer<ReadingPlanDetails?>>[];

  /// When true, calls to [getBooksStats] wait until the corresponding
  /// completer in [statsRequests] is completed.
  bool queueStatsRequests = false;
  final statsRequests = <Completer<List<RsBookStats>>>[];

  /// When true, calls to [getDayActivity] wait until the corresponding
  /// completer in [dayActivityRequests] is completed.
  bool queueDayActivityRequests = false;
  final dayActivityRequests = <Completer<DayActivity>>[];

  /// When set, day activity queries throw this instead of returning data.
  Object? dayActivityError;

  /// Start time assigned to sessions created through [addManualSession].
  DateTime nextManualSessionStartTime = DateTime(2026, 11, 17, 9, 30);

  int _nextSessionId = 1000;

  /// Number of times [getReadingPlanById] has been called.
  int getPlanByIdCalls = 0;

  ReadingPlanDetails? _detailsFor(int planId) =>
      plans.where((plan) => plan.readingPlan.id == planId).firstOrNull;

  @override
  Future<ReadingPlanDetails?> getReadingPlanById(int planId) {
    getPlanByIdCalls++;
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
  Future<void> addManualSession({
    required int readingPlanId,
    required DateTime date,
    required double minutes,
    required int verses,
  }) async {
    final call = AddManualSessionCall(
      readingPlanId: readingPlanId,
      date: date,
      minutes: minutes,
      verses: verses,
    );
    addedManualSessions.add(call);

    final readSeconds = (minutes * 60).round();
    final session = SessionActivity(
      sessionId: _nextSessionId++,
      startTime: nextManualSessionStartTime,
      readSeconds: readSeconds,
      verses: verses,
      isManual: true,
      ranges: const [],
    );
    queries?.dayActivity = [...?queries?.dayActivity, session];
  }

  @override
  Future<void> deleteManualSession(int sessionId) async {
    deletedManualSessionIds.add(sessionId);
    final current = queries?.dayActivity;
    if (current != null) {
      queries!.dayActivity = current
          .where((session) => session.sessionId != sessionId)
          .toList();
    }
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
  Future<int> saveReadingPlan({
    int? planId,
    required String planName,
    required GoalType goalType,
    required int goalValue,
    required List<int> bookIds,
  }) async {
    final call = SaveReadingPlanCall(
      planId: planId,
      planName: planName,
      goalType: goalType,
      goalValue: goalValue,
      bookIds: List.of(bookIds),
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
      return queuedPlan.id;
    }

    _storeSavedPlan(call, plan);
    return plan.id;
  }

  repo.ReadingPlan _planFor(SaveReadingPlanCall call) {
    final existing = call.planId == null || call.planId == 0
        ? null
        : _detailsFor(call.planId!)?.readingPlan;
    final plan = repo.ReadingPlan(
      id: existing?.id ?? _nextPlanId++,
      planName: call.planName,
      createdAt: existing?.createdAt ?? DateTime.now(),
      goalType: call.goalType,
      goalValue: call.goalValue,
      isBookmarked: existing?.isBookmarked ?? false,
      bookIds: call.bookIds,
    );
    savedPlans.add(plan);
    return plan;
  }

  void _storeSavedPlan(SaveReadingPlanCall call, repo.ReadingPlan plan) {
    final details = ReadingPlanDetails(
      ReadingPlan(
        id: plan.id,
        planName: plan.planName,
        createdAt: plan.createdAt,
        goalType: plan.goalType.name,
        goalValue: plan.goalValue,
        isBookmarked: plan.isBookmarked,
      ),
      [
        for (var i = 0; i < plan.bookIds.length; i++)
          ReadingPlanBook(
            readingPlanId: plan.id,
            bookId: plan.bookIds[i],
            ord: i + 1,
          ),
      ],
    );

    final index = plans.indexWhere(
      (existing) => existing.readingPlan.id == plan.id,
    );
    if (index == -1) {
      plans.add(details);
    } else {
      plans[index] = details;
    }

    queries?.configs[plan.id] = ReadingPlanConfig(
      planId: plan.id,
      planName: plan.planName,
      isBookmarked: plan.isBookmarked,
      createdAt: plan.createdAt,
      dailyGoal: DailyGoal(plan.goalType, plan.goalValue),
      bookIds: plan.bookIds,
    );
  }

  int _nextPlanId = 100;

  @override
  Future<void> setReadingPlanBookmark(int planId, bool isBookmarked) async {
    final error = bookmarkError;
    if (error != null) throw error;

    bookmarkedValues.add(isBookmarked);
    final details = _detailsFor(planId);
    if (details != null) {
      details.readingPlan = details.readingPlan.copyWith(
        isBookmarked: isBookmarked,
      );
    }
  }

  @override
  Future<void> reorderReadingPlanBooks(
    int readingPlanId,
    List<int> bookIds,
  ) async {
    final error = reorderError;
    if (error != null) throw error;

    final ordered = List<int>.of(bookIds);
    reorderedBooks.add(ordered);
    final details = _detailsFor(readingPlanId);
    if (details != null) {
      final index = plans.indexWhere(
        (plan) => plan.readingPlan.id == readingPlanId,
      );
      plans[index] = ReadingPlanDetails(details.readingPlan, [
        for (var i = 0; i < ordered.length; i++)
          ReadingPlanBook(
            readingPlanId: readingPlanId,
            bookId: ordered[i],
            ord: i + 1,
          ),
      ])..resumePosition = details.resumePosition;
    }
  }

  @override
  Future<void> deleteReadingPlan(int planId) async {
    final error = deleteError;
    if (error != null) throw error;

    if (queueDeleteRequests) {
      final request = Completer<void>();
      deleteRequests.add(request);
      await request.future;
    }

    deletedPlanIds.add(planId);
    plans = plans.where((plan) => plan.readingPlan.id != planId).toList();
    queries?.configs.remove(planId);
  }
}

class SaveReadingPlanCall {
  const SaveReadingPlanCall({
    required this.planId,
    required this.planName,
    required this.goalType,
    required this.goalValue,
    required this.bookIds,
  });

  final int? planId;
  final String planName;
  final GoalType goalType;
  final int goalValue;
  final List<int> bookIds;
}

class SaveReadingPlanRequest {
  SaveReadingPlanRequest(this.plan);

  final repo.ReadingPlan plan;
  final _completer = Completer<repo.ReadingPlan>();

  Future<repo.ReadingPlan> get future => _completer.future;

  void complete([repo.ReadingPlan? plan]) =>
      _completer.complete(plan ?? this.plan);

  void completeError(Object error) => _completer.completeError(error);
}

class AddManualSessionCall {
  const AddManualSessionCall({
    required this.readingPlanId,
    required this.date,
    required this.minutes,
    required this.verses,
  });

  final int readingPlanId;
  final DateTime date;
  final double minutes;
  final int verses;
}
