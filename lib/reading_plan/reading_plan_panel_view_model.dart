import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanPanelViewModel extends ChangeNotifier {
  ReadingPlanPanelViewModel._({
    required ReadingPlanService planService,
    required ReadingSessionViewModel sessionViewModel,
  }) : _planService = planService,
       _sessionViewModel = sessionViewModel;

  static Future<ReadingPlanPanelViewModel> create({
    ReadingPlanService? planService,
    ReadingSessionViewModel? sessionViewModel,
  }) async {
    final viewModel = ReadingPlanPanelViewModel._(
      planService: planService ?? getIt<ReadingPlanService>(),
      sessionViewModel: sessionViewModel ?? getIt<ReadingSessionViewModel>(),
    );

    try {
      viewModel._plans = await viewModel._planService
          .getReadingPlansWithProgress();
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }

    return viewModel;
  }

  void _setState(VoidCallback fn) {
    if (_disposed) return;
    fn();
    notifyListeners();
  }

  final ReadingPlanService _planService;
  final ReadingSessionViewModel _sessionViewModel;

  late List<ReadingPlanDetails> _plans;
  List<ReadingPlanDetails> get plans => _plans;

  final _refreshScope = CancellationScope();
  Future<void> refresh() {
    return _refreshScope.run((guard) async {
      final plans = await guard(_planService.getReadingPlansWithProgress());
      _setState(() {
        _plans = plans;
      });
    });
  }

  Future<void> deletePlan(int planId) async {
    await _planService.deleteReadingPlan(planId);
    await refresh();
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
