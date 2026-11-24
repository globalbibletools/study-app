import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/rs_database.dart';

import 'fake_reading_plan_read_models.dart';

class FakeReadingSessionDatabase extends Fake
    implements ReadingSessionDatabase {
  FakeReadingSessionDatabase(this.models);

  final FakeReadingPlanReadModels models;

  @override
  ReadingPlanReadModels get readModels => models;
}
