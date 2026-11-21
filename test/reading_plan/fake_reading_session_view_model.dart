import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';

class FakeReadingSessionViewModel extends Fake
    implements ReadingSessionViewModel {
  final startedPlanIds = <int>[];

  @override
  Future<void> startSession(int planId) async {
    startedPlanIds.add(planId);
  }
}
