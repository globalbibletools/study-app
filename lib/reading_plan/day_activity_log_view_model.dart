import 'package:flutter/foundation.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class DayActivityLogViewModel extends ChangeNotifier {
  factory DayActivityLogViewModel({
    required int readingPlanId,
    required DateTime date,
  }) {
    final viewModel = DayActivityLogViewModel.withDependencies(
      readingPlanId: readingPlanId,
      date: date,
      planService: getIt<ReadingPlanService>(),
    );
    viewModel._initFuture = viewModel.refresh();
    return viewModel;
  }

  DayActivityLogViewModel.withDependencies({
    required this.readingPlanId,
    required this.date,
    required ReadingPlanService planService,
  }) : _planService = planService;

  final ReadingPlanService _planService;

  final int readingPlanId;
  final DateTime date;

  List<SessionDetails> _sessions = const [];
  List<SessionDetails> get sessions => _sessions;

  int get sessionCount => _sessions.length;

  int get totalSeconds =>
      _sessions.fold(0, (sum, session) => sum + session.rsSession.readSeconds);

  int get totalMinutes => totalSeconds ~/ 60;

  int get totalVerses =>
      _sessions.fold(0, (sum, session) => sum + session.rsSession.verses);

  int minutesFor(SessionDetails session) => session.rsSession.readSeconds ~/ 60;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  Object? _loadError;
  Object? get loadError => _loadError;

  bool _disposed = false;

  Future<void>? _initFuture;
  Future<void> get ready => _initFuture ??= refresh();

  Future<void>? _refreshFuture;

  Future<void> refresh() {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;

    final future = _refresh();
    _refreshFuture = future;
    return future;
  }

  Future<void> _refresh() async {
    _isRefreshing = true;
    _loadError = null;
    notifyListeners();

    try {
      final sessions = await _planService.getDetailedProgressFor(
        date,
        readingPlanId,
      );
      if (_disposed) return;
      _sessions = sessions;
    } catch (error) {
      if (_disposed) return;
      _loadError = error;
    } finally {
      _isRefreshing = false;
      _refreshFuture = null;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
