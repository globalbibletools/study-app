import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/serial_queue.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/ui/reading_session_view_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanDetailViewModel extends ChangeNotifier {
  ReadingPlanDetailViewModel._({
    required int planId,
    required ReadingPlanQueries queries,
    required ReadingPlanService planService,
    required ReadingSessionViewModel sessionViewModel,
  }) : _planId = planId,
       _queries = queries,
       _planService = planService,
       _sessionViewModel = sessionViewModel;

  static Future<ReadingPlanDetailViewModel> create({
    required int planId,
    ReadingPlanQueries? queries,
    ReadingPlanService? planService,
    ReadingSessionViewModel? sessionViewModel,
  }) async {
    final viewModel = ReadingPlanDetailViewModel._(
      planId: planId,
      queries: queries ?? getIt<ReadingPlanQueries>(),
      planService: planService ?? getIt<ReadingPlanService>(),
      sessionViewModel: sessionViewModel ?? getIt<ReadingSessionViewModel>(),
    );

    try {
      await viewModel.refresh();
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }

    return viewModel;
  }

  final ReadingPlanQueries _queries;
  final ReadingPlanService _planService;
  final ReadingSessionViewModel _sessionViewModel;

  final _commands = SerialQueue();

  Future<void> refresh() {
    return _commands.runCoalesced('refresh', () async {
      final summary = await _queries.getPlanSummary(_planId);
      if (summary == null) throw StateError('Reading plan not found');

      final todaysProgress = await _queries.getDayProgress(
        _planId,
        DateTime.now(),
      );
      final monthProgress = await _queries.getMonthDayProgress(
        _planId,
        _visibleMonth,
      );

      _setState(() {
        _summary = summary;
        _monthProgress = monthProgress;
        _todaysProgress = todaysProgress;
      });
    });
  }

  // Plan basics

  final int _planId;
  int get planId => _planId;

  late ReadingPlanSummary _summary;
  String get planName => _summary.planName;

  bool get isBookmarked => _summary.isBookmarked;

  Future<void> toggleBookmark() {
    return _commands.runCoalesced('bookmark', () async {
      final isBookmarked = !_summary.isBookmarked;
      await _planService.setReadingPlanBookmark(_planId, isBookmarked);
      _setState(() {
        _summary = _summary.copyWith(
          config: _summary.config.copyWith(isBookmarked: isBookmarked),
        );
      });
    });
  }

  // Book progress

  Map<int, BookProgress> get bookStats => _summary.bookProgress;

  List<int> get bookIds => _summary.bookIds;

  double progressForBook(int bookId) {
    final stats = _summary.bookProgress[bookId];
    if (stats == null || stats.totalVerses <= 0) return 0;

    return (stats.versesRead / stats.totalVerses).clamp(0.0, 1.0);
  }

  // Start session

  Reference get readingReference => _summary.resumeTarget;

  Future<void> startReadingSession() {
    return _sessionViewModel.startSession(_planId);
  }

  // Total Progress

  bool get hasStarted => versesRead > 0;
  int get totalVerses => _summary.totalVerses;
  int get versesRead => _summary.versesRead;
  int get booksRead => _summary.booksRead;

  double get overallProgress =>
      totalVerses > 0 ? versesRead / totalVerses : 0.0;

  bool get hasEstimate => ReadingPlanEstimates.hasEstimate(
    remainingVerses: totalVerses - versesRead,
    goalType: goalType,
    goalValue: goalValue,
  );
  int get estimatedDays => ReadingPlanEstimates.daysFor(
    remainingVerses: totalVerses - versesRead,
    goalType: goalType,
    goalValue: goalValue,
  );
  DateTime get estimatedCompletionDate =>
      DateTime.now().add(Duration(days: estimatedDays));

  // Day Progress

  GoalType get goalType => _summary.dailyGoal.type;
  int get goalValue => _summary.dailyGoal.value;

  late DailyProgress _todaysProgress;
  DailyProgress get todaysProgress => _todaysProgress;

  double get todaysGoalProgress => _dayGoalFraction(_todaysProgress);

  DailyProgress? dayProgress(int day) => _monthProgress[day];

  // Calendar data and navigation

  static DateTime _monthStart(DateTime value) =>
      DateTime(value.year, value.month);

  DateTime _visibleMonth = _monthStart(DateTime.now());
  DateTime get visibleMonth => _visibleMonth;

  Map<int, DailyProgress> _monthProgress = const {};
  Map<int, double> get calendarProgress => {
    for (final entry in _monthProgress.entries)
      entry.key: _dayGoalFraction(entry.value),
  };

  double _dayGoalFraction(DailyProgress progress) {
    if (progress.goalReached) return 1;

    final goal = progress.goal;
    final type = goal?.type ?? goalType;
    final value = goal?.value ?? goalValue;
    if (value <= 0) return 0;

    final read = type == GoalType.verses ? progress.verses : progress.minutes;
    return (read / value).clamp(0.0, 1.0);
  }

  Future<void> showPreviousMonth() => _commands.run(() => _loadMonthStats(-1));
  Future<void> showNextMonth() => _commands.run(() => _loadMonthStats(1));

  Future<void> _loadMonthStats(int delta) async {
    final month = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final data = await _queries.getMonthDayProgress(_planId, month);
    _setState(() {
      _visibleMonth = month;
      _monthProgress = data;
    });
  }

  // Lifecycle utils

  bool _disposed = false;
  void _setState(VoidCallback fn) {
    if (_disposed) return;
    fn();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(() async {
      await _commands.close();

      super.dispose();
    }());
  }
}
