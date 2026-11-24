import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanPanelViewModel extends ChangeNotifier {
  ReadingPlanPanelViewModel._({
    required ReadingPlanReadModels readModels,
    required ReadingSessionViewModel sessionViewModel,
  }) : _readModels = readModels,
       _sessionViewModel = sessionViewModel;

  static Future<ReadingPlanPanelViewModel> create({
    ReadingPlanReadModels? readModels,
    ReadingSessionViewModel? sessionViewModel,
  }) async {
    final viewModel = ReadingPlanPanelViewModel._(
      readModels: readModels ?? getIt<ReadingSessionDatabase>().readModels,
      sessionViewModel: sessionViewModel ?? getIt<ReadingSessionViewModel>(),
    );

    try {
      viewModel._plans = await viewModel._readModels.getPlanSummaries();
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }

    return viewModel;
  }

  final ReadingPlanReadModels _readModels;
  final ReadingSessionViewModel _sessionViewModel;

  List<ReadingPlanSummary> _plans = const [];
  List<ReadingPlanSummary> get plans => _plans;

  final _refreshScope = CancellationScope();
  Future<void> refresh() {
    return _refreshScope.run((guard) async {
      final plans = await guard(_readModels.getPlanSummaries());
      _setState(() {
        _plans = plans;
      });
    });
  }

  Future<void> startReadingSession(ReadingPlanSummary plan) async {
    await _sessionViewModel.startSession(plan.planId);
  }

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
    super.dispose();
  }
}
