import 'package:flutter/material.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';
import 'package:studyapp/services/reading_session/rs_model.dart';
import 'package:studyapp/services/service_locator.dart';

enum MainTab { progress, goals }

enum ProgressTab { bySection, byBook }

enum GoalsTab { byWeek, byMonth }

class DetailedProgressPanelManager {
  final _rsManager = getIt<ReadingSessionManager>();

  final details = ValueNotifier<List<Session>>([]);

  final DateTime date;

  DetailedProgressPanelManager(this.date) {
    _rsManager.getDetailedProgressFor(date).then((value) {
      details.value = value;
    });
  }

  void dispose() {
    details.dispose();
  }
}
