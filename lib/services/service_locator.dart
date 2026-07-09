import 'package:get_it/get_it.dart';
import 'package:gbt/app_state.dart';
import 'package:gbt/services/app_guide/app_guide_manager.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/services/audio/audio_database.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/files/file_service.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/lexicon/database.dart';
import 'package:gbt/services/resources/resource_service.dart';

import 'settings/user_settings.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<FileService>(() => FileService());
  getIt.registerLazySingleton<RemoteAssetService>(() => RemoteAssetService());
  getIt.registerLazySingleton<HebrewGreekDatabase>(() => HebrewGreekDatabase());
  getIt.registerLazySingleton<GlossService>(() => GlossService());
  getIt.registerLazySingleton<LexiconsDatabase>(() => LexiconsDatabase());
  getIt.registerLazySingleton<UserSettings>(() => UserSettings());
  getIt.registerLazySingleton<AppState>(() => AppState());
  getIt.registerLazySingleton<DownloadService>(() => DownloadService());
  getIt.registerSingleton<BibleService>(BibleService());
  getIt.registerLazySingleton<AudioDatabase>(() => AudioDatabase());
  getIt.registerLazySingleton<ResourceService>(() => ResourceService());
  getIt.registerLazySingleton<ReadingSessionDatabase>(
    () => ReadingSessionDatabase(),
  );
  getIt.registerSingleton<ReadingSessionManager>(ReadingSessionManager());
  getIt.registerSingleton<AppGuideManager>(AppGuideManager());
}
