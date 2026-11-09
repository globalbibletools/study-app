import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/reading_plan_config.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/service_locator.dart';

class ReadingSessionServiceV2 {
  ReadingSessionServiceV2()
    : this.withDatabase(getIt<ReadingSessionDatabase>());

  ReadingSessionServiceV2.withDatabase(this._database);

  final ReadingSessionDatabase _database;
  late final _bibleNavigation = getIt<BibleNavigation>();

  Future<ReadingPlanConfig?> startSession(int planId) async {
    final details = await _database.getReadingPlanById(planId);
    if (details == null) return null;

    return ReadingPlanConfig.fromPlanDetails(details, _bibleNavigation);
  }
}
