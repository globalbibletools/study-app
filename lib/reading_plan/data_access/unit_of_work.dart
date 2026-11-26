import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/data_access/verse_state_repository.dart';
import 'package:sqflite/sqflite.dart';

/// A set of repositories bound to one transaction executor.
///
/// A [UnitOfWork] is created by [ReadingSessionDatabase.unitOfWork] and only
/// lives for the duration of that closure. Every repository read and write
/// made through it participates in the same transaction: the transaction
/// commits when the closure succeeds and rolls back when it throws.
///
/// Units of work must never nest. Sqflite has no nested transactions, so a
/// `unitOfWork` call inside another `unitOfWork` (or a service calling
/// another service's unit-of-work method while already inside one) is a bug,
/// not something the database will handle for you.
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

  /// The transaction executor backing this unit of work.
  ///
  /// Prefer the repositories; this is an escape hatch for low-level queries.
  final DatabaseExecutor executor;

  final SessionRepository session;
  final SessionLogRepository sessionLog;
  final VerseStateRepository verseState;
  final DaySummaryRepository daySummary;
  final ReadingPlanRepository readingPlans;
}
