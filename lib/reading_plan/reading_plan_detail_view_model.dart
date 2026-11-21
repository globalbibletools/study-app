import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/reading_plan/reading_plan_estimates.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';

class ReadingPlanDetailViewModel extends ChangeNotifier {
  ReadingPlanDetailViewModel({required ReadingPlanDetails plan})
    : this.withDependencies(
        plan: plan,
        planService: getIt<ReadingPlanService>(),
        sessionViewModel: getIt<ReadingSessionViewModel>(),
      );

  ReadingPlanDetailViewModel.withDependencies({
    required ReadingPlanDetails plan,
    required ReadingPlanService planService,
    required ReadingSessionViewModel sessionViewModel,
  }) : _planId = plan.readingPlan.id!,
       _readingPlan = plan.readingPlan,
       _planName = plan.readingPlan.planName,
       _isBookmarked = plan.readingPlan.isBookmarked,
       _books = List.of(plan.books),
       _goalType = plan.dailyGoal.type,
       _goalValue = plan.dailyGoal.value,
       _resumePosition = plan.resumePosition,
       _planService = planService,
       _sessionViewModel = sessionViewModel;

  final int _planId;
  final ReadingPlanService _planService;
  final ReadingSessionViewModel _sessionViewModel;

  ReadingPlan _readingPlan;
  String _planName;
  bool _isBookmarked;
  List<ReadingPlanBook> _books;
  GoalType _goalType;
  int _goalValue;
  Reference? _resumePosition;

  Map<int, RsBookStats> _bookStats = const {};
  Map<int, RsBookStats> get bookStats => _bookStats;

  int _totalVerses = 0;
  int get totalVerses => _totalVerses;

  int _versesRead = 0;
  int get versesRead => _versesRead;

  int _booksRead = 0;
  int get booksRead => _booksRead;

  DayProgress? _todaysProgress;
  DayProgress? get todaysProgress => _todaysProgress;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Object? _loadError;
  Object? get loadError => _loadError;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  final ValueNotifier<List<DayProgress>> _monthProgress = ValueNotifier([]);
  ValueListenable<List<DayProgress>> get monthProgress => _monthProgress;

  bool _disposed = false;

  void _setState(VoidCallback fn) {
    if (_disposed) return;
    fn();
    notifyListeners();
  }

  final _refreshScope = CancellationScope();
  final _monthScope = CancellationScope();
  final _reorderScope = CancellationScope();

  Future<void>? _initialization;
  Future<void> initialize() => _initialization ??= refresh();

  String get planName => _planName;
  int get planId => _planId;
  ReadingPlanDetails get planDetails =>
      ReadingPlanDetails(_readingPlan, List.of(_books));
  bool get isBookmarked => _isBookmarked;
  List<ReadingPlanBook> get books => _books;
  GoalType get goalType => _goalType;
  int get goalValue => _goalValue;
  Reference? get resumePosition => _resumePosition;
  bool get hasStarted => _versesRead > 0;

  Reference get readingReference {
    final resumePosition = _resumePosition;
    if (resumePosition != null) return resumePosition;

    return Reference(
      bookId: _books.isNotEmpty ? _books.first.bookId : 1,
      chapter: 1,
      verse: 1,
    );
  }

  double get overallProgress =>
      _totalVerses > 0 ? _versesRead / _totalVerses : 0.0;

  int get progressPercent => (overallProgress * 100).round();

  double get todaysGoalProgress {
    if (_goalValue <= 0) return 0;
    final progress = _todaysProgress;
    final read = progress == null
        ? 0
        : _goalType == GoalType.verses
        ? progress.verses
        : progress.minutes;
    return read / _goalValue;
  }

  bool get goalReachedToday => todaysGoalProgress >= 1;

  int get todaysGoalPercent =>
      (todaysGoalProgress.clamp(0.0, 1.0) * 100).round();

  int get _remainingVerses => _totalVerses - _versesRead;

  bool get hasEstimate => ReadingPlanEstimates.hasEstimate(
    remainingVerses: _remainingVerses,
    goalType: _goalType,
    goalValue: _goalValue,
  );

  int get estimatedDays => ReadingPlanEstimates.daysFor(
    remainingVerses: _remainingVerses,
    goalType: _goalType,
    goalValue: _goalValue,
  );

  double get estimatedMonths =>
      ReadingPlanEstimates.monthsForDays(estimatedDays);

  DateTime get estimatedCompletionDate =>
      DateTime.now().add(Duration(days: estimatedDays));

  double progressForBook(int bookId) {
    final stats = _bookStats[bookId];
    if (stats == null || stats.totalVerses <= 0) return 0;

    return (stats.versesRead / stats.totalVerses).clamp(0.0, 1.0);
  }

  bool isBookComplete(int bookId) => _bookStats[bookId]?.isComplete ?? false;

  Future<void> reloadPlan() async {
    final details = await _planService.getReadingPlanById(_planId);
    if (_disposed || details == null) return;

    _setState(() {
      _readingPlan = details.readingPlan;
      _planName = details.readingPlan.planName;
      _isBookmarked = details.readingPlan.isBookmarked;
      _books = List.of(details.books);
      _goalType = details.dailyGoal.type;
      _goalValue = details.dailyGoal.value;
      _resumePosition = details.resumePosition;
    });

    await refresh();
  }

  Future<void> refresh() {
    return _refreshScope.run(_refresh);
  }

  Future<void> _refresh(Guard guard) async {
    var cancelled = false;
    _setState(() {
      _isRefreshing = true;
      _loadError = null;
    });

    try {
      final now = DateTime.now();

      final loaded = await guard(_planService.getBooksStats(_planId));
      final statsByBook = {for (final stat in loaded) stat.bookId: stat};

      final resumePosition = await guard(
        _planService.getResumeReference(_planId),
      );

      final month = await guard(
        _planService.getMonthProgress(
          _planId,
          DateTime(now.year, now.month, 1),
        ),
      );

      var totalVerses = 0;
      var versesRead = 0;
      var booksRead = 0;
      for (final book in _books) {
        final stat = statsByBook[book.bookId];
        totalVerses += stat?.totalVerses ?? 0;
        versesRead += stat?.versesRead ?? 0;
        if (stat != null && stat.isComplete) {
          booksRead += 1;
        }
      }

      _setState(() {
        _bookStats = statsByBook;
        _totalVerses = totalVerses;
        _versesRead = versesRead;
        _booksRead = booksRead;
        _resumePosition = resumePosition;
        _monthProgress.value = month;
        _todaysProgress = now.day <= month.length ? month[now.day - 1] : null;
        _isInitialized = true;
      });
    } on CancelledError {
      cancelled = true;
      rethrow;
    } catch (error) {
      _setState(() {
        _loadError = error;
      });
    } finally {
      if (!cancelled) {
        _setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> toggleBookmark() async {
    final wasBookmarked = _isBookmarked;
    _setState(() {
      _isBookmarked = !wasBookmarked;
      _readingPlan = _readingPlan.copyWith(isBookmarked: _isBookmarked);
    });

    try {
      final updatedPlan = await _planService.setReadingPlanBookmark(
        _readingPlan,
        _isBookmarked,
      );
      _setState(() {
        _readingPlan = updatedPlan;
        _isBookmarked = updatedPlan.isBookmarked;
      });
    } on CancelledError {
      rethrow;
    } catch (_) {
      _setState(() {
        _isBookmarked = wasBookmarked;
        _readingPlan = _readingPlan.copyWith(isBookmarked: wasBookmarked);
      });

      await refresh();
    }
  }

  Future<void> loadMonthData(DateTime month) {
    return _monthScope.run((guard) async {
      final data = await guard(_planService.getMonthProgress(_planId, month));
      _setState(() {
        _monthProgress.value = data;
      });
    });
  }

  Future<void> startReadingSession() {
    return _sessionViewModel.startSession(_planId);
  }

  Future<void> moveBook(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _books.length) return;
    if (newIndex < 0 || newIndex >= _books.length) return;

    _setState(() {
      final book = _books.removeAt(oldIndex);
      _books.insert(newIndex, book);
    });

    await _persistBookOrder();
  }

  Future<void> _persistBookOrder() {
    return _reorderScope.run((guard) async {
      final orderedBooks = [
        for (int i = 0; i < _books.length; i++)
          _books[i].copyWith(readingPlanId: _planId, ord: i + 1),
      ];
      _setState(() {
        _books = orderedBooks;
      });

      await guard(_planService.reorderReadingPlanBooks(_planId, orderedBooks));
      await guard(refresh());
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshScope.cancelAll();
    _monthScope.cancelAll();
    _reorderScope.cancelAll();
    _monthProgress.dispose();
    super.dispose();
  }
}
