import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/serial_queue.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/ui/reading_session_view_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanPanelViewModel extends ChangeNotifier {
  final _queries = getIt<ReadingPlanQueries>();
  final _sessionViewModel = getIt<ReadingSessionViewModel>();

  ReadingPlanPanelViewModel._();

  static Future<ReadingPlanPanelViewModel> create() async {
    final viewModel = ReadingPlanPanelViewModel._();

    try {
      viewModel._plans = await viewModel._queries.getPlanSummaries();
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }

    return viewModel;
  }

  late List<ReadingPlanSummary> _plans;
  List<ReadingPlanSummary> get plans => _plans;

  final _commands = SerialQueue();

  Future<void> refresh() {
    return _commands.runCoalesced('refresh', () async {
      final plans = await _queries.getPlanSummaries();
      _setState(() {
        _plans = plans;
      });
    });
  }

  Future<void> startReadingSession(ReadingPlanSummary plan) {
    return _sessionViewModel.startSession(plan.planId);
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
    unawaited(() async {
      await _commands.close();

      super.dispose();
    }());
  }
}
