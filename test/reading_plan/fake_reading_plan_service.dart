import 'dart:async';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';

import 'fake_reading_plan_read_models.dart';

class FakeReadingPlanService extends Fake implements ReadingPlanService {
  FakeReadingPlanService([List<ReadingPlanSummary>? plans])
    : plans = plans ?? [];

  List<ReadingPlanSummary> plans;

  FakeReadingPlanReadModels? readModels;

  final addedManualSessions = <AddManualSessionCall>[];
  final deletedManualSessionIds = <int>[];
  final deletedPlanIds = <int>[];
  final bookmarkedValues = <bool>[];
  final saveCalls = <SaveReadingPlanCall>[];

  /// When set, bookmark writes throw this instead of persisting.
  Object? bookmarkError;

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

  /// Start time assigned to sessions created through [addManualSession].
  DateTime nextManualSessionStartTime = DateTime(2026, 11, 17, 9, 30);

  int _nextSessionId = 1000;
  int _nextPlanId = 100;

  ReadingPlanSummary? _summaryFor(int planId) =>
      plans.where((plan) => plan.planId == planId).firstOrNull;

  void _syncReadModels() {
    readModels?.plans = plans;
  }

  @override
  Future<int> addManualSession({
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
    final session = RsSession(
      id: _nextSessionId++,
      rsDate: dayOnly(date),
      startTime: nextManualSessionStartTime,
      endTime: nextManualSessionStartTime.add(Duration(seconds: readSeconds)),
      readSeconds: readSeconds,
      verses: verses,
      readingPlanId: readingPlanId,
      isManual: true,
    );
    final fakeReadModels = readModels;
    if (fakeReadModels != null) {
      fakeReadModels.detailedProgress = [
        ...fakeReadModels.detailedProgress,
        SessionDetails(session, const []),
      ];
    }
    return session.id!;
  }

  @override
  Future<bool> deleteManualSession(int sessionId) async {
    deletedManualSessionIds.add(sessionId);
    final fakeReadModels = readModels;
    if (fakeReadModels != null) {
      fakeReadModels.detailedProgress = fakeReadModels.detailedProgress
          .where((session) => session.rsSession.id != sessionId)
          .toList();
    }
    return true;
  }

  @override
  Future<int> saveReadingPlan({
    int? planId,
    required String planName,
    required int collectionId,
    required GoalType goalType,
    required int goalValue,
    required Set<int> selectedBookIds,
    List<int>? orderedBookIds,
  }) async {
    final call = SaveReadingPlanCall(
      planId: planId,
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
      return queuedPlan.planId;
    }

    _storeSavedPlan(call, plan);
    return plan.planId;
  }

  ReadingPlanSummary _planFor(SaveReadingPlanCall call) {
    final existing = call.planId == null ? null : _summaryFor(call.planId!);
    final orderedBookIds =
        call.orderedBookIds ?? (call.selectedBookIds.toList()..sort());
    final planId = existing?.planId ?? _nextPlanId++;
    final books = [
      for (var i = 0; i < orderedBookIds.length; i++)
        ReadingPlanBook(
          readingPlanId: planId,
          bookId: orderedBookIds[i],
          ord: i + 1,
        ),
    ];
    final existingProgress = existing?.progress.bookProgress ?? const {};
    final config = ReadingPlanConfig(
      planId: planId,
      planName: call.planName,
      collectionId: call.collectionId,
      isBookmarked: existing?.isBookmarked ?? false,
      createdAt: existing?.config.createdAt ?? DateTime.now(),
      dailyGoal: DailyGoal(call.goalType, call.goalValue),
      books: books,
    );
    final progress = ReadingPlanProgress(
      planId: planId,
      bookProgress: {
        for (final book in books)
          book.bookId: BookProgress(
            bookId: book.bookId,
            totalVerses: existingProgress[book.bookId]?.totalVerses ?? 0,
            versesRead: existingProgress[book.bookId]?.versesRead ?? 0,
          ),
      },
      resumePosition: existing?.progress.resumePosition,
    );
    return ReadingPlanSummary(
      config: config,
      progress: progress,
      today: existing?.today ?? DayProgress.empty(DateTime.now()),
    );
  }

  void _storeSavedPlan(SaveReadingPlanCall call, ReadingPlanSummary plan) {
    final index = plans.indexWhere(
      (existing) => existing.planId == plan.planId,
    );
    if (index == -1) {
      plans.add(plan);
    } else {
      plans[index] = plan;
    }
    _syncReadModels();
  }

  @override
  Future<void> setReadingPlanBookmark(int planId, bool isBookmarked) async {
    final error = bookmarkError;
    if (error != null) throw error;

    final summary = _summaryFor(planId);
    if (summary == null) throw StateError('Reading plan not found: $planId');

    bookmarkedValues.add(isBookmarked);
    final config = summary.config;
    final updated = ReadingPlanSummary(
      config: ReadingPlanConfig(
        planId: config.planId,
        planName: config.planName,
        collectionId: config.collectionId,
        isBookmarked: isBookmarked,
        createdAt: config.createdAt,
        dailyGoal: config.dailyGoal,
        books: config.books,
      ),
      progress: summary.progress,
      today: summary.today,
    );
    final index = plans.indexWhere((existing) => existing.planId == planId);
    plans[index] = updated;
    _syncReadModels();
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
    plans = plans.where((plan) => plan.planId != planId).toList();
    _syncReadModels();
  }
}

class SaveReadingPlanCall {
  const SaveReadingPlanCall({
    required this.planId,
    required this.planName,
    required this.collectionId,
    required this.goalType,
    required this.goalValue,
    required this.selectedBookIds,
    required this.orderedBookIds,
  });

  final int? planId;
  final String planName;
  final int collectionId;
  final GoalType goalType;
  final int goalValue;
  final Set<int> selectedBookIds;
  final List<int>? orderedBookIds;
}

class SaveReadingPlanRequest {
  SaveReadingPlanRequest(this.plan);

  final ReadingPlanSummary plan;
  final _completer = Completer<ReadingPlanSummary>();

  Future<ReadingPlanSummary> get future => _completer.future;

  void complete([ReadingPlanSummary? plan]) =>
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
