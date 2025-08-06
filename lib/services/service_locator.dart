import 'package:get_it/get_it.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/lexicon/database.dart';

import 'user_settings.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<HebrewGreekDatabase>(() => HebrewGreekDatabase());
  getIt.registerLazySingleton<GlossService>(() => GlossService());
  getIt.registerLazySingleton<LexiconsDatabase>(() => LexiconsDatabase());
  getIt.registerLazySingleton<UserSettings>(() => UserSettings());
  getIt.registerLazySingleton<AppState>(() => AppState());
}
