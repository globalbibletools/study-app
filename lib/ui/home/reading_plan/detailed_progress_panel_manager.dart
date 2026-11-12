import 'package:flutter/material.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class DetailedProgressPanelManager {
  final _planService = getIt<ReadingPlanService>();

  final details = ValueNotifier<List<SessionDetails>>([]);

  final int readingPlanId;
  final DateTime date;
  bool _isDisposed = false;

  DetailedProgressPanelManager(this.readingPlanId, this.date) {
    _planService.getDetailedProgressFor(date, readingPlanId).then((value) {
      if (!_isDisposed) {
        details.value = value;
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    details.dispose();
  }
}
