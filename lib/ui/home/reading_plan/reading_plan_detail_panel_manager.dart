import 'package:flutter/material.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/reading_session_service.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingPlanDetailPanelManager {
  final _rsManager = getIt<ReadingSessionService>();
  final _planService = getIt<ReadingPlanService>();

  final readingPlansNotifier = ValueNotifier<List<ReadingPlanDetails>>([]);
  final booksProgressNotifier = ValueNotifier<List<RsBookStats>>([]);
  final todaysProgressNotifier = ValueNotifier<DayProgress?>(null);
  final bookmarkNotifier = ValueNotifier<bool>(false);
  final monthProgress = ValueNotifier<List<DayProgress>>([]);
  final resumePositionNotifier = ValueNotifier<Reference?>(null);

  ReadingPlanDetails readingPlanDetails;
  bool _isDisposed = false;
  late final Future<void> _initFuture;

  ReadingPlanDetailPanelManager(this.readingPlanDetails) {
    bookmarkNotifier.value = readingPlanDetails.readingPlan.isBookmarked;
    resumePositionNotifier.value = readingPlanDetails.resumePosition;
    _initFuture = init();
  }

  Future<void> get ready => _initFuture;

  Future<void> init() async {
    final planId = readingPlanDetails.readingPlan.id!;
    final now = DateTime.now();

    final loaded = await _planService.getBooksStats(planId);
    final statsByBook = {for (final stat in loaded) stat.bookId: stat};
    var totalVerses = 0;
    var versesRead = 0;
    var booksRead = 0;
    for (final book in readingPlanDetails.books) {
      final stat = statsByBook[book.bookId];
      totalVerses += stat?.totalVerses ?? 0;
      versesRead += stat?.versesRead ?? 0;
      if (stat != null && stat.isComplete) {
        booksRead += 1;
      }
    }
    final resumePosition = await _planService.getResumeReference(planId);
    final month = await _planService.getMonthProgress(
      planId,
      DateTime(now.year, now.month, 1),
    );

    if (_isDisposed) return;

    readingPlanDetails.totalVerses = totalVerses;
    readingPlanDetails.versesRead = versesRead;
    readingPlanDetails.booksRead = booksRead;
    booksProgressNotifier.value = loaded;
    readingPlanDetails.resumePosition = resumePosition;
    resumePositionNotifier.value = resumePosition;
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
    resumePositionNotifier.dispose();
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
    final resumePosition = await _planService.getResumeReference(
      readingPlanDetails.readingPlan.id!,
    );
    if (_isDisposed) return;
    readingPlanDetails.resumePosition = resumePosition;
    resumePositionNotifier.value = resumePosition;
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
