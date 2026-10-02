import 'package:flutter/material.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanDetailPanelManager {
  final _rsManager = getIt<ReadingSessionManager>();
  final _rsdbManager = getIt<ReadingSessionDatabase>();

  final readingPlansNotifier = ValueNotifier<List<ReadingPlanDetails>>([]);
  final booksProgressNotifier = ValueNotifier<List<RsBookProgress>>([]);
  final todaysProgressNotifier = ValueNotifier<DayProgress?>(null);
  final bookmarkNotifier = ValueNotifier<bool>(false);
  final monthProgress = ValueNotifier<List<DayProgress>>([]);

  ReadingPlanDetails readingPlanDetails;

  ReadingPlanDetailPanelManager(this.readingPlanDetails) {
    init();
    DateTime now = DateTime.now();
    loadMonthData(DateTime(now.year, now.month, 1));
  }

  void init() async {
    final planId = readingPlanDetails.readingPlan.id!;
    bookmarkNotifier.value = readingPlanDetails.readingPlan.isBookmarked;
    _rsManager.subsribeForStats(onStatsUpdated);
    booksProgressNotifier.value = await _rsManager.loadBooksProgress(planId);
    await onStatsUpdated();
  }

  Future<void> onStatsUpdated() async {
    final planId = readingPlanDetails.readingPlan.id!;
    List<DayProgress>? progress = await _rsManager.getMonthProgress(planId);

    final now = DateTime.now();

    if (progress != null) {
      todaysProgressNotifier.value = progress[now.day - 1];
    }
  }

  Future<void> markToggleReadingPlanBookmark() async {
    readingPlanDetails.readingPlan = readingPlanDetails.readingPlan.copyWith(
      isBookmarked: !readingPlanDetails.readingPlan.isBookmarked,
    );
    await _rsdbManager.updateReadingPlan(readingPlanDetails.readingPlan);

    bookmarkNotifier.value = readingPlanDetails.readingPlan.isBookmarked;
  }

  void dispose() {
    _rsManager.unsubsribeForStats(onStatsUpdated);
  }

  Future<void> startReadingSession() async {
    _rsManager.startReadingSession(readingPlanDetails);
  }

  void reorderBooks(List<ReadingPlanBook> books) {
    for (int i = 0; i < books.length; i++) {
      books[i] = books[i].copyWith(ord: i + 1);
    }
    _rsdbManager.updateReadingPlanBooks(books);
  }

  void loadMonthData(DateTime month) async {
    monthProgress.value = await _rsManager.loadMonthProgress(
      readingPlanDetails.readingPlan.id!,
      month,
    );
  }
}
