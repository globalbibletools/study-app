import 'package:flutter/material.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

enum MainTab { progress, goals }

enum ProgressTab { bySection, byBook }

enum BookProgressTab { christian, jewish, easyToHard }

enum GoalsTab { byWeek, byMonth }

class ReadingPlanPanelManager {
  final _rsManager = getIt<ReadingSessionManager>();
  final _rsdbManager = getIt<ReadingSessionDatabase>();

  final readingPlansNotifier = ValueNotifier<List<ReadingPlanDetails>>([]);

  ReadingPlanPanelManager() {
    init();
  }

  void init() async {
    List<ReadingPlanDetails> plans = await _rsdbManager.getReadingPlans();

    for (ReadingPlanDetails p in plans) {
      int totalChapters = 0;
      int versesCount = 0;
      int versesRead = 0;
      int booksRead = 0;

      List<RsBookProgress> booksProgress = await _rsManager.loadBooksProgress(
        p.readingPlan.id!,
      );

      for (ReadingPlanBook b in p.books) {
        int bookChap = BibleNavigation.getChapterCount(b.bookId);
        int bookVerses = BibleNavigation.getTotalVerseCount(b.bookId);

        totalChapters += bookChap;
        versesCount += bookVerses;

        versesRead += booksProgress[b.bookId - 1].versesRead;

        if (booksProgress[b.bookId - 1].versesRead >= bookVerses) {
          booksRead += 1;
        }
      }

      p.totalChapters = totalChapters;
      p.totalVerses = versesCount;
      p.versesRead = versesRead;
      p.booksRead = booksRead;
      p.latestBookProgress = _rsManager.getLatestBookProgress(
        p.readingPlan.id!,
      );
    }

    readingPlansNotifier.value = plans;
  }

  void dispose() {}

  Future<void> startReadingSession(ReadingPlanDetails readingPlan) async {
    await _rsManager.startReadingSession(readingPlan);
  }
}
