import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/data_access/verse_state_repository.dart';
import 'package:sqflite/sqflite.dart';

class UnitOfWork {
  UnitOfWork(
    this.executor, {
    required VerseInventoryProvider verseInventoryProvider,
  }) : session = SessionRepository(executor),
       sessionLog = SessionLogRepository(executor),
       verseState = VerseStateRepository(
         executor,
         verseInventoryProvider: verseInventoryProvider,
       ),
       daySummary = DaySummaryRepository(executor),
       readingPlans = ReadingPlanRepository(executor);

  final DatabaseExecutor executor;

  final SessionRepository session;
  final SessionLogRepository sessionLog;
  final VerseStateRepository verseState;
  final DaySummaryRepository daySummary;
  final ReadingPlanRepository readingPlans;
}
