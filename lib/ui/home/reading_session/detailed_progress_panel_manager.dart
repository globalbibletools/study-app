import 'package:flutter/material.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

enum MainTab { progress, goals }

enum ProgressTab { bySection, byBook }

enum GoalsTab { byWeek, byMonth }

class DetailedProgressPanelManager {
  final _rsManager = getIt<ReadingSessionManager>();

  final details = ValueNotifier<List<Session>>([]);

  final DateTime date;

  DetailedProgressPanelManager(this.date) {
    reload();
  }

  Future<void> reload() async {
    details.value = await _rsManager.getDetailedProgressFor(date);
  }

  void dispose() {
    details.dispose();
  }
}
