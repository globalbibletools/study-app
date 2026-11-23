import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/reading_plan/reading_plan_estimates.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';

class ReadingPlanDetailViewModel extends ChangeNotifier {
  ReadingPlanDetailViewModel({required int planId})
    : this.withDependencies(
        planId: planId,
        planService: getIt<ReadingPlanService>(),
        sessionViewModel: getIt<ReadingSessionViewModel>(),
      );

  ReadingPlanDetailViewModel.withDependencies({
    required int planId,
    required ReadingPlanService planService,
    required ReadingSessionViewModel sessionViewModel,
  }) : _planId = planId,
       _planService = planService,
       _sessionViewModel = sessionViewModel;

  final ReadingPlanService _planService;
  final ReadingSessionViewModel _sessionViewModel;

  Object? _loadError;
  Object? get loadError => _loadError;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  Future<void>? _initialization;
  Future<void> initialize() => _initialization ??= refresh();

  final _refreshScope = CancellationScope();

  Future<void> refresh() {
    return _refreshScope.run((guard) async {
      if (_loadError != null) {
        _setState(() {
          _loadError = null;
        });
      }

      try {
        final details = await guard(_planService.getReadingPlanById(_planId));
        if (_disposed) return;
        if (details == null) {
          _setState(() {
            _loadError = StateError('Reading plan not found');
            _isInitialized = true;
          });
          return;
        }

        final stats = await guard(_planService.getBooksStats(_planId));
        final statsByBook = {for (final stat in stats) stat.bookId: stat};

        final todaysProgress = await guard(
          _planService.getDayProgress(_planId, DateTime.now()),
        );
        final monthProgress = await guard(
          _planService.getMonthProgress(_planId, _visibleMonth),
        );

        _setState(() {
          _planDetails = details;
          _bookStats = statsByBook;
          _monthProgress = monthProgress;
          _todaysProgress = todaysProgress;
          _isInitialized = true;
        });
      } on CancelledError {
        rethrow;
      } catch (error) {
        _setState(() {
          _loadError = error;
        });
      }
    });
  }

  // Plan basics

  final int _planId;
  int get planId => _planId;

  ReadingPlanDetails? _planDetails;
  String get planName => _planDetails?.readingPlan.planName ?? '';

  ReadingPlanDetails get planDetails {
    final details = _planDetails;
    if (details == null) {
      throw StateError('Reading plan details have not been loaded');
    }
    return details;
  }

  bool get isBookmarked => _planDetails?.readingPlan.isBookmarked ?? false;
  Future<void> toggleBookmark() async {
    final plan = _planDetails;
    if (plan == null) return;

    final updatedPlan = await _planService.setReadingPlanBookmark(
      plan.readingPlan,
      !plan.readingPlan.isBookmarked,
    );
    _setState(() {
      plan.readingPlan = updatedPlan;
    });
  }

  // Book progress

  Map<int, RsBookStats> _bookStats = const {};
  Map<int, RsBookStats> get bookStats => _bookStats;

  List<ReadingPlanBook> get books => _planDetails?.books ?? const [];

  double progressForBook(int bookId) {
    final stats = _bookStats[bookId];
    if (stats == null || stats.totalVerses <= 0) return 0;

    return (stats.versesRead / stats.totalVerses).clamp(0.0, 1.0);
  }

  // Start session

  Reference get readingReference {
    final resumePosition = _planDetails?.resumePosition;
    if (resumePosition != null) return resumePosition;

    return Reference(
      bookId: books.isNotEmpty ? books.first.bookId : 1,
      chapter: 1,
      verse: 1,
    );
  }

  Future<void> startReadingSession() {
    return _sessionViewModel.startSession(_planId);
  }

  // Total Progress

  bool get hasStarted => versesRead > 0;

  int get totalVerses {
    var total = 0;
    for (final book in books) {
      total += _bookStats[book.bookId]?.totalVerses ?? 0;
    }
    return total;
  }

  int get versesRead {
    var read = 0;
    for (final book in books) {
      read += _bookStats[book.bookId]?.versesRead ?? 0;
    }
    return read;
  }

  int get booksRead {
    var read = 0;
    for (final book in books) {
      if (_bookStats[book.bookId]?.isComplete ?? false) read += 1;
    }
    return read;
  }

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

  GoalType get goalType => _planDetails?.dailyGoal.type ?? GoalType.verses;
  int get goalValue => _planDetails?.dailyGoal.value ?? 0;

  DayProgress? _todaysProgress;
  DayProgress? get todaysProgress => _todaysProgress;

  double get todaysGoalProgress {
    if (goalValue <= 0) return 0;
    final progress = _todaysProgress;
    final read = progress == null
        ? 0
        : goalType == GoalType.verses
        ? progress.verses
        : progress.minutes;
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
      final data = await guard(_planService.getMonthProgress(_planId, month));
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
