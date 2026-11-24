import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/services/service_locator.dart';

class DayActivityLogViewModel extends ChangeNotifier {
  DayActivityLogViewModel._({
    required this.readingPlanId,
    required this.date,
    required ReadingPlanReadModels readModels,
    required ReadingPlanService planService,
  }) : _readModels = readModels,
       _planService = planService;

  static Future<DayActivityLogViewModel> create({
    required int readingPlanId,
    required DateTime date,
    ReadingPlanReadModels? readModels,
    ReadingPlanService? planService,
  }) async {
    final viewModel = DayActivityLogViewModel._(
      readingPlanId: readingPlanId,
      date: date,
      readModels: readModels ?? getIt<ReadingSessionDatabase>().readModels,
      planService: planService ?? getIt<ReadingPlanService>(),
    );

    try {
      viewModel._sessions = await viewModel._readModels.getDayActivity(
        readingPlanId,
        date,
      );
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }

    return viewModel;
  }

  final ReadingPlanReadModels _readModels;
  final ReadingPlanService _planService;

  final _refreshScope = CancellationScope();

  Future<void> refresh() {
    return _refreshScope.run((guard) async {
      final sessions = await guard(
        _readModels.getDayActivity(readingPlanId, date),
      );
      _setState(() {
        _sessions = sessions;
      });
    });
  }

  Future<void> addManualSession({
    required double minutes,
    required int verses,
  }) async {
    await _planService.addManualSession(
      readingPlanId: readingPlanId,
      date: date,
      minutes: minutes,
      verses: verses,
    );
    await refresh();
  }

  Future<void> deleteManualSession(int sessionId) async {
    await _planService.deleteManualSession(sessionId);
    await refresh();
  }

  final int readingPlanId;
  final DateTime date;

  late List<SessionDetails> _sessions;
  List<SessionDetails> get sessions => _sessions;

  double get totalMinutes {
    final totalSeconds = _sessions.fold(
      0,
      (sum, session) => sum + session.rsSession.readSeconds,
    );
    return _roundMinutes(totalSeconds / 60);
  }

  int get totalVerses =>
      _sessions.fold(0, (sum, session) => sum + session.rsSession.verses);

  double minutesFor(SessionDetails session) =>
      _roundMinutes(session.rsSession.readSeconds / 60);

  List<VerseRange> referencesFor(SessionDetails session) {
    return [...session.progress]..sort((a, b) {
      final byBook = a.bookId.compareTo(b.bookId);
      if (byBook != 0) return byBook;
      final byChapter = a.chapter.compareTo(b.chapter);
      if (byChapter != 0) return byChapter;
      return a.fromVerse.compareTo(b.fromVerse);
    });
  }

  double _roundMinutes(num minutes) => (minutes * 10).round() / 10;

  void _setState(VoidCallback fn) {
    if (_disposed) return;
    fn();
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _refreshScope.cancelAll();
    super.dispose();
  }
}
