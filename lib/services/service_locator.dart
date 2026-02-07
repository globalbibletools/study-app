import 'package:get_it/get_it.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/services/audio/audio_database.dart';
import 'package:studyapp/services/bible/bible_service.dart';
import 'package:studyapp/services/download/download.dart';
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/lexicon/database.dart';

import 'user_settings.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<FileService>(() => FileService());
  getIt.registerLazySingleton<HebrewGreekDatabase>(() => HebrewGreekDatabase());
  getIt.registerLazySingleton<GlossService>(() => GlossService());
  getIt.registerLazySingleton<LexiconsDatabase>(() => LexiconsDatabase());
  getIt.registerLazySingleton<UserSettings>(() => UserSettings());
  getIt.registerLazySingleton<AppState>(() => AppState());
  getIt.registerLazySingleton<DownloadService>(() => DownloadService());
  getIt.registerSingleton<BibleService>(BibleService());
  getIt.registerLazySingleton<AudioDatabase>(() => AudioDatabase());
}
