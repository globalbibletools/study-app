import 'package:flutter/material.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';
import 'package:studyapp/services/reading_session/rs_model.dart';
import 'package:studyapp/services/service_locator.dart';

enum MainTab { progress, goals }

enum ProgressTab { bySection, byBook }

enum BookProgressTab { christian, jewish, easyToHard }

enum GoalsTab { byWeek, byMonth }

class ReadingSessionPanelManager {
  final _rsManager = getIt<ReadingSessionManager>();

  final booksProgressNotifier = ValueNotifier<List<RsBookProgress>>([]);
  final latestBookProgressNotifier = ValueNotifier<RsBookProgress?>(null);
  final goalsDataNotifier = ValueNotifier<List<DayProgress>>([]);

  final selectedMainTab = ValueNotifier<MainTab>(MainTab.progress);
  final selectedPTabNotifier = ValueNotifier<ProgressTab>(ProgressTab.byBook);
  final selectedGTabNotifier = ValueNotifier<GoalsTab>(GoalsTab.byWeek);
  final selectedBPTabNotifier = ValueNotifier<BookProgressTab>(BookProgressTab.christian);

  final dailyGoalNotifier = ValueNotifier<DailyGoal?>(null);

  ReadingSessionPanelManager() {
    _rsManager.subsribeForBookProgress(onBookProgressUpdated);
    _rsManager.subsribeForStats(onStatsUpdated);
    selectedGTabNotifier.addListener(onStatsUpdated);
    booksProgressNotifier.value = _rsManager.booksProgress;
    latestBookProgressNotifier.value = _rsManager.latestBookProgress;
    dailyGoalNotifier.value = _rsManager.getDailyGoal();

    if (dailyGoalNotifier.value == null) {
      selectedMainTab.value = MainTab.goals;
      selectedGTabNotifier.value = GoalsTab.byWeek;
    }

    onStatsUpdated();
  }

  void onBookProgressUpdated() {
    booksProgressNotifier.value = _rsManager.booksProgress;
    latestBookProgressNotifier.value = _rsManager.latestBookProgress;
  }

  void onStatsUpdated() {
    if (selectedGTabNotifier.value == GoalsTab.byMonth) {
      goalsDataNotifier.value = _rsManager.monthProgress;
    } else {
      goalsDataNotifier.value = _rsManager.weekProgress;
    }
  }

  void updateGoal(GoalType type, int value) {
    _rsManager.setDailyGoal(type, value);
    dailyGoalNotifier.value = DailyGoal(type, value);
  }

  void dispose() {
    _rsManager.unsubsribeForBookProgress(onBookProgressUpdated);
    _rsManager.unsubsribeForStats(onStatsUpdated);
  }
}
