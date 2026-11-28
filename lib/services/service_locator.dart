import 'package:get_it/get_it.dart';
import 'package:gbt/app_state.dart';
import 'package:gbt/changelog/changelog_service.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/app_guide/app_guide_manager.dart';
import 'package:gbt/reading_plan/reading_plan_backup_service.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/reading_plan/ui/reading_session_view_model.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/files/file_service.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/lexicon/database.dart';
import 'package:gbt/services/logging/app_logger.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

import 'settings/user_settings.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerSingletonAsync<UserSettings>(() async {
    final settings = UserSettings();
    await settings.init();
    return settings;
  });
  getIt.registerSingletonAsync<NavigationViewModel>(
    () async => NavigationViewModel(await getIt.getAsync<UserSettings>()),
  );
  // TODO: Maybe we should delay loading the lexicon until it is needed.
  getIt.registerSingletonAsync<LexiconsDatabase>(() async {
    final database = LexiconsDatabase();
    await database.init();
    return database;
  });
  getIt.registerSingletonAsync<ReadingSessionDatabase>(() async {
    final settings = await getIt.getAsync<UserSettings>();
    final database = ReadingSessionDatabase(
      legacyDailyGoal: settings.legacyDailyGoal,
      verseInventoryProvider: (bookIds) async {
        final hebrewGreek = await getIt.getAsync<HebrewGreekDatabase>();
        return hebrewGreek.getVerseInventory(bookIds: bookIds);
      },
    );
    await database.init();
    await settings.clearLegacyDailyGoal();
    return database;
  });
  getIt.registerLazySingleton<ReadingPlanQueries>(
    () => getIt<ReadingSessionDatabase>().queries,
  );
  getIt.registerLazySingleton<FileService>(() => FileService());
  getIt.registerLazySingleton<RemoteAssetService>(() => RemoteAssetService());
  getIt.registerLazySingletonAsync<HebrewGreekDatabase>(
    HebrewGreekDatabase.create,
  );
  getIt.registerSingletonAsync<BibleNavigation>(
    () async =>
        BibleNavigation.create(await getIt.getAsync<HebrewGreekDatabase>()),
  );
  getIt.registerLazySingleton<GlossService>(() => GlossService());
  getIt.registerLazySingleton<AppState>(() => AppState());
  getIt.registerSingletonAsync<AppLogger>(AppLogger.createDefault);
  getIt.registerLazySingleton<DownloadService>(() => DownloadService());
  getIt.registerLazySingleton<BibleService>(() => BibleService());
  getIt.registerLazySingleton<ResourceService>(() => ResourceService());
  getIt.registerLazySingleton<ReadingPlanBackupService>(
    () => ReadingPlanBackupService(),
  );
  getIt.registerLazySingleton<ReadingPlanService>(() => ReadingPlanService());
  getIt.registerLazySingleton<ReadingSessionService>(
    () => ReadingSessionService(),
  );
  getIt.registerLazySingleton<ReadingSessionViewModel>(
    () => ReadingSessionViewModel(),
  );
  getIt.registerLazySingleton<AppGuideManager>(() => AppGuideManager());
  getIt.registerLazySingleton<ChangelogService>(() => ChangelogService());
  getIt.registerLazySingleton<HomeManager>(() => HomeManager());
  getIt.registerLazySingleton<MessengerViewModel>(() => MessengerViewModel());
}
