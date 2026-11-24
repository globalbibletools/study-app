import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_estimates.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanDetailViewModel extends ChangeNotifier {
  ReadingPlanDetailViewModel._({
    required int planId,
    required ReadingPlanReadModels readModels,
    required ReadingPlanService planService,
    required ReadingSessionViewModel sessionViewModel,
  }) : _planId = planId,
       _readModels = readModels,
       _planService = planService,
       _sessionViewModel = sessionViewModel;

  static Future<ReadingPlanDetailViewModel> create({
    required int planId,
    ReadingPlanReadModels? readModels,
    ReadingPlanService? planService,
    ReadingSessionViewModel? sessionViewModel,
  }) async {
    final viewModel = ReadingPlanDetailViewModel._(
      planId: planId,
      readModels: readModels ?? getIt<ReadingSessionDatabase>().readModels,
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

  final ReadingPlanReadModels _readModels;
  final ReadingPlanService _planService;
  final ReadingSessionViewModel _sessionViewModel;

  final _refreshScope = CancellationScope();

  Future<void> refresh() {
    return _refreshScope.run((guard) async {
      final summary = await guard(_readModels.getPlanSummary(_planId));
      if (summary == null) throw StateError('Reading plan not found');

      final monthProgress = await guard(
        _readModels.getMonthProgress(_planId, _visibleMonth),
      );

      _setState(() {
        _summary = summary;
        _monthProgress = monthProgress;
      });
    });
  }

  // Plan basics

  final int _planId;
  int get planId => _planId;

  ReadingPlanSummary? _summary;
  ReadingPlanSummary get summary {
    final summary = _summary;
    if (summary == null) {
      throw StateError('Reading plan details have not been loaded');
    }
    return summary;
  }

  String get planName => _summary?.planName ?? '';

  bool get isBookmarked => _summary?.isBookmarked ?? false;

  Future<void> toggleBookmark() async {
    final summary = _summary;
    if (summary == null) return;

    final isBookmarked = !summary.isBookmarked;
    await _planService.setReadingPlanBookmark(_planId, isBookmarked);

    _setState(() {
      _summary = summary.copyWith(
        config: summary.config.copyWith(isBookmarked: isBookmarked),
      );
    });
  }

  // Book progress

  Map<int, BookProgress> get bookStats => _summary?.bookProgress ?? const {};

  List<ReadingPlanBook> get books => _summary?.books ?? const [];

  double progressForBook(int bookId) {
    final stats = _summary?.bookProgress[bookId];
    if (stats == null || stats.totalVerses <= 0) return 0;

    return (stats.versesRead / stats.totalVerses).clamp(0.0, 1.0);
  }

  // Start session

  Reference get readingReference => summary.resumeTarget;

  Future<void> startReadingSession() {
    return _sessionViewModel.startSession(_planId);
  }

  // Total Progress

  bool get hasStarted => versesRead > 0;
  int get totalVerses => _summary?.totalVerses ?? 0;
  int get versesRead => _summary?.versesRead ?? 0;
  int get booksRead => _summary?.booksRead ?? 0;

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

  GoalType get goalType => _summary?.dailyGoal.type ?? GoalType.verses;
  int get goalValue => _summary?.dailyGoal.value ?? 0;

  DayProgress get todaysProgress {
    final summary = _summary;
    if (summary == null) {
      throw StateError('Reading plan progress has not been loaded');
    }
    return summary.today;
  }

  double get todaysGoalProgress {
    if (goalValue <= 0) return 0;
    final read = goalType == GoalType.verses
        ? todaysProgress.verses
        : todaysProgress.minutes;
    return read / goalValue;
  }

  DayProgress? dayProgress(int day) {
    for (final progress in _monthProgress) {
      if (progress.day.year == _visibleMonth.year &&
          progress.day.month == _visibleMonth.month &&
          progress.day.day == day) {
        return progress;
      }
    }
    return null;
  }

  // Calendar data and navigation

  static DateTime _monthStart(DateTime value) =>
      DateTime(value.year, value.month);

  DateTime _visibleMonth = _monthStart(DateTime.now());
  DateTime get visibleMonth => _visibleMonth;

  List<DayProgress> _monthProgress = const [];
  Map<int, double> get calendarProgress => {
    for (final progress in _monthProgress)
      if (!progress.empty) progress.day.day: _dayGoalFraction(progress),
  };

  double _dayGoalFraction(DayProgress progress) {
    if (progress.goalReached) return 1;
    if (goalValue <= 0) return 0;

    final read = goalType == GoalType.verses
        ? progress.verses
        : progress.minutes;
    return (read / goalValue).clamp(0.0, 1.0);
  }

  Future<void> showPreviousMonth() => _loadMonthStats(-1);
  Future<void> showNextMonth() => _loadMonthStats(1);

  final _monthScope = CancellationScope();
  Future<void> _loadMonthStats(int delta) async {
    return _monthScope.run((guard) async {
      final month = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      final data = await guard(_readModels.getMonthProgress(_planId, month));
      _setState(() {
        _visibleMonth = month;
        _monthProgress = data;
      });
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
    _refreshScope.cancelAll();
    _monthScope.cancelAll();
    super.dispose();
  }
}
