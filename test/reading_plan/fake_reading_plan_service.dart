import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';

class FakeReadingPlanService extends Fake implements ReadingPlanService {
  FakeReadingPlanService([List<ReadingPlanDetails>? plans])
    : plans = plans ?? [];

  List<ReadingPlanDetails> plans;
  final deletedPlanIds = <int>[];

  /// When true, calls to [getReadingPlansWithProgress] wait until the
  /// corresponding completer in [getRequests] is completed.
  bool queueGetRequests = false;
  final getRequests = <Completer<List<ReadingPlanDetails>>>[];

  /// When set, deletes wait for this to complete before taking effect.
  Completer<void>? deleteGate;

  @override
  Future<List<ReadingPlanDetails>> getReadingPlansWithProgress() {
    if (queueGetRequests) {
      final request = Completer<List<ReadingPlanDetails>>();
      getRequests.add(request);
      return request.future;
    }
    return Future.value(List.of(plans));
  }

  @override
  Future<void> deleteReadingPlan(int planId) async {
    final gate = deleteGate;
    if (gate != null) await gate.future;

    deletedPlanIds.add(planId);
    plans = plans.where((plan) => plan.readingPlan.id != planId).toList();
  }
}
