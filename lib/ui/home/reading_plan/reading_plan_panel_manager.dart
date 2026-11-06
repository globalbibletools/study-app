import 'package:flutter/material.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanPanelManager {
  final _rsManager = getIt<ReadingSessionManager>();

  final readingPlansNotifier = ValueNotifier<List<ReadingPlanDetails>>([]);

  ReadingPlanPanelManager() {
    init();
  }

  Future<void> init() async {
    final plans = await _rsManager.getReadingPlansWithProgress();
    readingPlansNotifier.value = plans;
  }

  Future<void> deleteReadingPlan(int planId) async {
    await _rsManager.deleteReadingPlan(planId);
    await init();
  }

  void dispose() {}

  Future<void> startReadingSession(ReadingPlanDetails readingPlan) async {
    await _rsManager.startReadingSession(readingPlan);
  }
}
