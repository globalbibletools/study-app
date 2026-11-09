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

  ReadingPlanDetailPanelManager(this.readingPlanDetails) {
    bookmarkNotifier.value = readingPlanDetails.readingPlan.isBookmarked;
    latestBookProgressNotifier.value = readingPlanDetails.latestBookProgress;
    _initFuture = init();
  }

  Future<void> get ready => _initFuture;

  Future<void> init() async {
    final planId = readingPlanDetails.readingPlan.id!;
    final orderedBookIds = readingPlanDetails.books
        .map((b) => b.bookId)
        .toList();
    final now = DateTime.now();

    final loaded = await _planService.getBooksProgress(planId);
    final latest = await _planService.getLatestBookProgress(
      planId,
      orderedBookIds: orderedBookIds,
    );
    final month = await _planService.getMonthProgress(
      planId,
      DateTime(now.year, now.month, 1),
    );

    if (_isDisposed) return;

    booksProgressNotifier.value = loaded;
    readingPlanDetails.latestBookProgress = latest;
    latestBookProgressNotifier.value = latest;
    monthProgress.value = month;
    todaysProgressNotifier.value = now.day <= month.length
        ? month[now.day - 1]
        : null;
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
    final latest = await _planService.getLatestBookProgress(
      readingPlanDetails.readingPlan.id!,
      orderedBookIds: orderedBookIds,
    );
    if (_isDisposed) return;
    readingPlanDetails.latestBookProgress = latest;
    latestBookProgressNotifier.value = latest;
  }

  Future<void> loadMonthData(DateTime month) async {
    final data = await _planService.getMonthProgress(
      readingPlanDetails.readingPlan.id!,
      month,
    );
    if (!_isDisposed) {
      monthProgress.value = data;
    }
  }
}
