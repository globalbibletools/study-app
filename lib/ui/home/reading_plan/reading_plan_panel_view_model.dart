import 'package:flutter/foundation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/reading_plan/reading_session_view_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanPanelViewModel extends ChangeNotifier {
  factory ReadingPlanPanelViewModel() {
    final viewModel = ReadingPlanPanelViewModel.withDependencies(
      planService: getIt<ReadingPlanService>(),
      sessionViewModel: getIt<ReadingSessionViewModel>(),
      homeManager: getIt<HomeManager>(),
    );
    viewModel._initFuture = viewModel.refresh();
    return viewModel;
  }

  ReadingPlanPanelViewModel.withDependencies({
    required ReadingPlanService planService,
    required ReadingSessionViewModel sessionViewModel,
    required HomeManager homeManager,
  }) : _planService = planService,
       _sessionViewModel = sessionViewModel,
       _homeManager = homeManager;

  final ReadingPlanService _planService;
  final ReadingSessionViewModel _sessionViewModel;
  final HomeManager _homeManager;

  List<ReadingPlanDetails> _plans = const [];
  List<ReadingPlanDetails> get plans => _plans;

  bool _isEditing = false;
  bool get isEditing => _isEditing;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  bool _disposed = false;

  Future<void>? _initFuture;
  Future<void> get ready => _initFuture ??= refresh();

  Future<void>? _refreshFuture;

  void toggleEditMode() {
    _isEditing = !_isEditing;
    notifyListeners();
  }

  void exitEditMode() {
    if (!_isEditing) return;
    _isEditing = false;
    notifyListeners();
  }

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
      final plans = await _planService.getReadingPlansWithProgress();
      if (_disposed) return;
      _plans = plans;
    } finally {
      _isRefreshing = false;
      _refreshFuture = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> deletePlan(ReadingPlanDetails plan) async {
    final planId = plan.readingPlan.id;
    if (planId == null) return;

    _plans = [
      for (final existing in _plans)
        if (existing.readingPlan.id != planId) existing,
    ];
    notifyListeners();

    try {
      await _planService.deleteReadingPlan(planId);
    } catch (_) {
      await refresh();
      rethrow;
    }
  }

  Future<void> startReadingSession(ReadingPlanDetails plan) async {
    await _sessionViewModel.startSession(plan.readingPlan.id!);
    _homeManager.jumpToReference(resumeTargetFor(plan));
  }

  Reference resumeTargetFor(ReadingPlanDetails plan) {
    return plan.resumePosition ??
        Reference(bookId: plan.books[0].bookId, chapter: 1, verse: 1);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
