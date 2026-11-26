import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/serial_queue.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/services/service_locator.dart';

class DayActivityLogViewModel extends ChangeNotifier {
  DayActivityLogViewModel._({
    required this.readingPlanId,
    required this.date,
    required ReadingPlanQueries queries,
    required ReadingPlanService planService,
  }) : _queries = queries,
       _planService = planService;

  static Future<DayActivityLogViewModel> create({
    required int readingPlanId,
    required DateTime date,
    ReadingPlanQueries? queries,
    ReadingPlanService? planService,
  }) async {
    final viewModel = DayActivityLogViewModel._(
      readingPlanId: readingPlanId,
      date: date,
      queries: queries ?? getIt<ReadingPlanQueries>(),
      planService: planService ?? getIt<ReadingPlanService>(),
    );

    try {
      viewModel._activity = await viewModel._queries.getDayActivity(
        readingPlanId,
        date,
      );
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }

    return viewModel;
  }

  final ReadingPlanQueries _queries;
  final ReadingPlanService _planService;

  final _commands = SerialQueue();

  Future<void> refresh() => _commands.runCoalesced('refresh', _refresh);

  Future<void> _refresh() async {
    final activity = await _queries.getDayActivity(readingPlanId, date);
    _setState(() {
      _activity = activity;
    });
  }

  Future<void> addManualSession({
    required double minutes,
    required int verses,
  }) {
    return _commands.run(() async {
      await _planService.addManualSession(
        readingPlanId: readingPlanId,
        date: date,
        minutes: minutes,
        verses: verses,
      );
      await _refresh();
    });
  }

  Future<void> deleteManualSession(int sessionId) {
    return _commands.runCoalesced('deleteSession:$sessionId', () async {
      await _planService.deleteManualSession(sessionId);
      await _refresh();
    });
  }

  final int readingPlanId;
  final DateTime date;

  late DayActivity _activity;
  List<SessionActivity> get sessions => _activity.sessions;

  double get totalMinutes => _activity.totalMinutes;

  int get totalVerses => _activity.totalVerses;

  double minutesFor(SessionActivity session) => session.minutes;

  List<VerseRange> referencesFor(SessionActivity session) => session.ranges;

  void _setState(VoidCallback fn) {
    if (_disposed) return;
    fn();
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    unawaited(() async {
      await _commands.close();

      super.dispose();
    }());
  }
}
