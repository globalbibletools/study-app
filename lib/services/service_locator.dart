import 'package:get_it/get_it.dart';
import 'package:studyapp/services/database.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<HebrewGreekDatabase>(() => HebrewGreekDatabase());
}
