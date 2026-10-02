import 'package:flutter/material.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

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
  final selectedBPTabNotifier = ValueNotifier<BookProgressTab>(
    BookProgressTab.christian,
  );

  ReadingSessionPanelManager() {
    _rsManager.subsribeForBookProgress(onBookProgressUpdated);
    _rsManager.subsribeForStats(onStatsUpdated);
    selectedGTabNotifier.addListener(onStatsUpdated);
    //booksProgressNotifier.value = _rsManager.booksProgress;
    latestBookProgressNotifier.value = _rsManager.latestBookProgress;

    selectedMainTab.value = MainTab.goals;
    selectedGTabNotifier.value = GoalsTab.byWeek;

    onStatsUpdated();
  }

  void onBookProgressUpdated() {
    //booksProgressNotifier.value = _rsManager.booksProgress;
    latestBookProgressNotifier.value = _rsManager.latestBookProgress;
  }

  void onStatsUpdated() {
    if (selectedGTabNotifier.value == GoalsTab.byMonth) {
      //goalsDataNotifier.value = _rsManager.monthProgress;
    } else {
      //goalsDataNotifier.value = _rsManager.weekProgress;
    }
  }

  void dispose() {
    _rsManager.unsubsribeForBookProgress(onBookProgressUpdated);
    _rsManager.unsubsribeForStats(onStatsUpdated);
  }
}
