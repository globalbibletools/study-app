import 'package:flutter/foundation.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/reading_plan/reading_plan_estimates.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';

class ReadingPlanDetailViewModel extends ChangeNotifier {
  factory ReadingPlanDetailViewModel({
    required ReadingPlanDetails plan,
    // TODO: why is this optional?
    HomeManager? homeManager,
  }) {
    final viewModel = ReadingPlanDetailViewModel.withDependencies(
      plan: plan,
      planService: getIt<ReadingPlanService>(),
      sessionViewModel: getIt<ReadingSessionViewModel>(),
      bibleNavigation: getIt<BibleNavigation>(),
      homeManager: homeManager ?? getIt<HomeManager>(),
    );
    viewModel._initFuture = viewModel.refresh();
    return viewModel;
  }

  ReadingPlanDetailViewModel.withDependencies({
    required ReadingPlanDetails plan,
    required ReadingPlanService planService,
    required ReadingSessionViewModel sessionViewModel,
    required BibleNavigation bibleNavigation,
    required HomeManager homeManager,
  }) : _planId = plan.readingPlan.id!,
       _readingPlan = plan.readingPlan,
       _planName = plan.readingPlan.planName,
       _isBookmarked = plan.readingPlan.isBookmarked,
       _books = List.of(plan.books),
       _goalType = plan.dailyGoal.type,
       _goalValue = plan.dailyGoal.value,
       _resumePosition = plan.resumePosition,
       _planService = planService,
       _sessionViewModel = sessionViewModel,
       _bibleNavigation = bibleNavigation,
       _homeManager = homeManager;

  final int _planId;
  final ReadingPlanService _planService;
  final ReadingSessionViewModel _sessionViewModel;
  final BibleNavigation _bibleNavigation;
  final HomeManager _homeManager;

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

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  bool _isReorderMode = false;
  bool get isReorderMode => _isReorderMode;

  /// The one public notifier: `CalendarView` requires a `ValueListenable`.
  final ValueNotifier<List<DayProgress>> monthProgress = ValueNotifier([]);

  bool _disposed = false;

  Future<void>? _initFuture;
  Future<void> get ready => _initFuture ??= refresh();

  Future<void>? _refreshFuture;

  String get planName => _planName;
  bool get isBookmarked => _isBookmarked;
  List<ReadingPlanBook> get books => _books;
  GoalType get goalType => _goalType;
  int get goalValue => _goalValue;
  Reference? get resumePosition => _resumePosition;

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
    if (stats == null) return 0;

    final totalVerses = _bibleNavigation.getTotalVerseCount(bookId);
    if (totalVerses <= 0) return 0;

    return stats.versesRead / totalVerses;
  }

  bool isBookComplete(int bookId) => progressForBook(bookId) >= 1;

  Reference get resumeTarget =>
      _resumePosition ??
      (_books.isNotEmpty
          ? Reference(bookId: _books.first.bookId, chapter: 1, verse: 1)
          : const Reference(bookId: 1, chapter: 1, verse: 1));

  Future<void> refresh() {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;

    final future = _refresh();
    _refreshFuture = future;
    return future;
  }

  Future<void> _refresh() async {
    _isRefreshing = true;
    notifyListeners();

    try {
      final now = DateTime.now();

      final loaded = await _planService.getBooksStats(_planId);
      if (_disposed) return;

      final statsByBook = {for (final stat in loaded) stat.bookId: stat};
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

      final resumePosition = await _planService.getResumeReference(_planId);
      if (_disposed) return;

      final month = await _planService.getMonthProgress(
        _planId,
        DateTime(now.year, now.month, 1),
      );
      if (_disposed) return;

      _bookStats = statsByBook;
      _totalVerses = totalVerses;
      _versesRead = versesRead;
      _booksRead = booksRead;
      _resumePosition = resumePosition;
      monthProgress.value = month;
      _todaysProgress = now.day <= month.length ? month[now.day - 1] : null;
    } finally {
      _isRefreshing = false;
      _refreshFuture = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> toggleBookmark() async {
    final wasBookmarked = _isBookmarked;
    _isBookmarked = !wasBookmarked;
    _readingPlan = _readingPlan.copyWith(isBookmarked: _isBookmarked);
    notifyListeners();

    try {
      final updatedPlan = await _planService.setReadingPlanBookmark(
        _readingPlan,
        _isBookmarked,
      );
      if (_disposed) return;

      _readingPlan = updatedPlan;
      _isBookmarked = updatedPlan.isBookmarked;
      notifyListeners();
    } catch (_) {
      if (_disposed) return;

      _isBookmarked = wasBookmarked;
      _readingPlan = _readingPlan.copyWith(isBookmarked: wasBookmarked);
      notifyListeners();

      try {
        await refresh();
      } catch (_) {
        // Keep the rollback state; surfacing persistence errors is a separate
        // UX decision.
      }
    }
  }

  Future<void> loadMonthData(DateTime month) async {
    final data = await _planService.getMonthProgress(_planId, month);
    if (_disposed) return;
    monthProgress.value = data;
  }

  Future<void> startReadingSession() async {
    await _sessionViewModel.startSession(_planId);
    if (_disposed) return;
    _homeManager.jumpToReference(resumeTarget);
  }

  Future<void> toggleReorderMode() async {
    _isReorderMode = !_isReorderMode;
    notifyListeners();

    // Persist the new order once the user finishes reordering.
    if (!_isReorderMode) {
      await _persistBookOrder();
    }
  }

  void moveBook(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _books.length) return;
    final book = _books.removeAt(oldIndex);
    _books.insert(newIndex, book);
    notifyListeners();
  }

  Future<void> _persistBookOrder() async {
    final orderedBooks = [
      for (int i = 0; i < _books.length; i++)
        _books[i].copyWith(readingPlanId: _planId, ord: i + 1),
    ];
    _books = orderedBooks;
    notifyListeners();

    await _planService.reorderReadingPlanBooks(_planId, orderedBooks);
    if (_disposed) return;

    final resumePosition = await _planService.getResumeReference(_planId);
    if (_disposed) return;

    _resumePosition = resumePosition;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    monthProgress.dispose();
    super.dispose();
  }
}
