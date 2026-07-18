import 'package:flutter/material.dart';
import 'package:gbt/app_state.dart';
import 'package:gbt/l10n/app_languages.dart';
import 'package:gbt/services/service_locator.dart';

import 'package:gbt/services/settings/user_settings.dart';

class SettingsManager extends ChangeNotifier {
  final _settings = getIt<UserSettings>();
  final appState = getIt<AppState>();

  Locale get currentLocale => _settings.locale;

  String get currentLanguageName {
    final config = AppLanguages.getConfig(currentLocale.languageCode);
    return config.nativeName;
  }

  Future<void> setLocale(Locale selectedLocale) async {
    await _settings.setLocale(selectedLocale.languageCode);
    appState.init();
    notifyListeners();
  }
}
