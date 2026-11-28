import 'package:gbt/services/settings/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UserSettings> createTestUserSettings({String? legacyDailyGoal}) async {
  SharedPreferences.setMockInitialValues({'rsDailyGoal': ?legacyDailyGoal});
  final settings = UserSettings();
  await settings.init();
  return settings;
}
