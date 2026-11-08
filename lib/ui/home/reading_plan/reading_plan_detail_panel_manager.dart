import 'package:flutter/material.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanDetailPanelManager {
  final _rsManager = getIt<ReadingSessionManager>();
  final _planService = getIt<ReadingPlanService>();

  final readingPlansNotifier = ValueNotifier<List<ReadingPlanDetails>>([]);
  final booksProgressNotifier = ValueNotifier<List<RsBookProgress>>([]);
  final todaysProgressNotifier = ValueNotifier<DayProgress?>(null);
  final bookmarkNotifier = ValueNotifier<bool>(false);
  final monthProgress = ValueNotifier<List<DayProgress>>([]);
  final latestBookProgressNotifier = ValueNotifier<RsBookProgress?>(null);

  ReadingPlanDetails readingPlanDetails;
  bool _isDisposed = false;
  late final Future<void> _initFuture;
  late final Future<void> _monthLoadFuture;

  ReadingPlanDetailPanelManager(this.readingPlanDetails) {
    bookmarkNotifier.value = readingPlanDetails.readingPlan.isBookmarked;
    final orderedBookIds = readingPlanDetails.books
        .map((b) => b.bookId)
        .toList();
    readingPlanDetails.latestBookProgress = _rsManager.getLatestBookProgress(
      readingPlanDetails.readingPlan.id!,
      orderedBookIds: orderedBookIds,
    );
    latestBookProgressNotifier.value = readingPlanDetails.latestBookProgress;
    _initFuture = init();
    DateTime now = DateTime.now();
    _monthLoadFuture = loadMonthData(DateTime(now.year, now.month, 1));
  }

  Future<void> get ready => Future.wait([_initFuture, _monthLoadFuture]);

  Future<void> init() async {
    final planId = readingPlanDetails.readingPlan.id!;
    _rsManager.subscribeForStats(onStatsUpdated);
    final loaded = await _rsManager.loadBooksProgress(planId);
    if (_isDisposed) return;
    booksProgressNotifier.value = loaded;
    final orderedBookIds = readingPlanDetails.books
        .map((b) => b.bookId)
        .toList();
    readingPlanDetails.latestBookProgress = _rsManager.getLatestBookProgress(
      planId,
      orderedBookIds: orderedBookIds,
    );
    latestBookProgressNotifier.value = readingPlanDetails.latestBookProgress;
    await onStatsUpdated();
  }

  Future<void> onStatsUpdated() async {
    if (_isDisposed) return;
    final planId = readingPlanDetails.readingPlan.id!;
    List<DayProgress>? progress = await _rsManager.getMonthProgress(planId);
    if (_isDisposed) return;

    final now = DateTime.now();

    if (progress != null && progress.isNotEmpty && now.day <= progress.length) {
      todaysProgressNotifier.value = progress[now.day - 1];
    }
  }

  Future<void> markToggleReadingPlanBookmark() async {
    final updatedPlan = await _planService.setReadingPlanBookmark(
      readingPlanDetails.readingPlan,
      !readingPlanDetails.readingPlan.isBookmarked,
    );
    readingPlanDetails.readingPlan = updatedPlan;
    bookmarkNotifier.value = updatedPlan.isBookmarked;
  }

  void dispose() {
    _isDisposed = true;
    _rsManager.unsubscribeForStats(onStatsUpdated);
    latestBookProgressNotifier.dispose();
  }

  Future<void> startReadingSession() async {
    await _rsManager.startReadingSession(readingPlanDetails);
  }

  Future<void> reorderBooks(List<ReadingPlanBook> books) async {
    final updatedBooks = <ReadingPlanBook>[];
    for (int i = 0; i < books.length; i++) {
      updatedBooks.add(books[i].copyWith(ord: i + 1));
    }
    readingPlanDetails.books
      ..clear()
      ..addAll(updatedBooks);
    await _planService.reorderReadingPlanBooks(
      readingPlanDetails.readingPlan.id!,
      updatedBooks,
    );
    final orderedBookIds = updatedBooks.map((b) => b.bookId).toList();
    readingPlanDetails.latestBookProgress = _rsManager.getLatestBookProgress(
      readingPlanDetails.readingPlan.id!,
      orderedBookIds: orderedBookIds,
    );
    latestBookProgressNotifier.value = readingPlanDetails.latestBookProgress;
  }

  Future<void> loadMonthData(DateTime month) async {
    final data = await _rsManager.loadMonthProgress(
      readingPlanDetails.readingPlan.id!,
      month,
    );
    if (!_isDisposed) {
      monthProgress.value = data;
    }
  }
}
