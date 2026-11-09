import 'package:flutter/foundation.dart';
import 'package:gbt/services/reading_session/reading_plan_config.dart';
import 'package:gbt/services/reading_session/reading_session_service_v2.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingSessionViewModel {
  ReadingSessionViewModel()
    : this.withService(getIt<ReadingSessionServiceV2>());

  ReadingSessionViewModel.withService(this._service);

  final ReadingSessionServiceV2 _service;

  final planConfigNotifier = ValueNotifier<ReadingPlanConfig?>(null);
  ReadingPlanConfig? get planConfig => planConfigNotifier.value;
  bool get hasActiveSession => planConfigNotifier.value != null;

  int _sessionLoadToken = 0;
  bool _disposed = false;

  Future<void> startSession(int planId) async {
    final token = ++_sessionLoadToken;
    final config = await _service.startSession(planId);
    if (_disposed || token != _sessionLoadToken) return;

    if (config == null) {
      throw StateError('Reading plan not found: $planId');
    }

    planConfigNotifier.value = config;
  }

  Future<void> endSession() async {
    _sessionLoadToken++;
    if (_disposed) return;
    planConfigNotifier.value = null;
  }

  void dispose() {
    _disposed = true;
    _sessionLoadToken++;
    planConfigNotifier.dispose();
  }
}
