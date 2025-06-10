import 'package:get_it/get_it.dart';
import 'package:studyapp/services/database.dart';

import 'user_settings.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<HebrewGreekDatabase>(() => HebrewGreekDatabase());
  getIt.registerLazySingleton<EnglishDatabase>(() => EnglishDatabase());
  getIt.registerLazySingleton<UserSettings>(() => UserSettings());
}
