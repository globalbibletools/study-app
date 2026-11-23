import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanPanelViewModel extends ChangeNotifier {
  ReadingPlanPanelViewModel()
    : this.withDependencies(
        planService: getIt<ReadingPlanService>(),
        sessionViewModel: getIt<ReadingSessionViewModel>(),
      );

  ReadingPlanPanelViewModel.withDependencies({
    required ReadingPlanService planService,
    required ReadingSessionViewModel sessionViewModel,
  }) : _planService = planService,
       _sessionViewModel = sessionViewModel;

  void _setState(VoidCallback fn) {
    if (_disposed) return;
    fn();
    notifyListeners();
  }

  final ReadingPlanService _planService;
  final ReadingSessionViewModel _sessionViewModel;

  List<ReadingPlanDetails> _plans = const [];
  List<ReadingPlanDetails> get plans => _plans;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void>? _initialization;
  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    final plans = await _planService.getReadingPlansWithProgress();
    _setState(() {
      _plans = plans;
      _isInitialized = true;
    });
  }

  final _refreshScope = CancellationScope();
  Future<void> refresh() {
    return _refreshScope.run((guard) async {
      final plans = await guard(_planService.getReadingPlansWithProgress());
      _setState(() {
        _plans = plans;
      });
    });
  }

  Future<void> startReadingSession(ReadingPlanDetails plan) async {
    final planId = plan.readingPlan.id;
    if (planId == null) return;

    await _sessionViewModel.startSession(planId);
  }

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    _refreshScope.cancelAll();
    super.dispose();
  }
}
