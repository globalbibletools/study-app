import 'package:flutter/material.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

enum Language {
  english('en'),
  spanish('es'),
  system(null);

  final String? code;
  const Language(this.code);
}

class SettingsManager extends ChangeNotifier {
  final userSettings = getIt<UserSettings>();
  final appState = getIt<AppState>();

  void setLanguage(Language selectedLanguage) {
    userSettings.setLocale(selectedLanguage.code);
    appState.init();
  }
}
