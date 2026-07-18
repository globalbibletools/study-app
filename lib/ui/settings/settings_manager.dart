import 'package:flutter/material.dart';
import 'package:gbt/app_state.dart';
import 'package:gbt/l10n/app_languages.dart';
import 'package:gbt/services/gloss/gloss_database.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/service_locator.dart';

import 'package:gbt/services/settings/user_settings.dart';

class SettingsManager extends ChangeNotifier {
  final _settings = getIt<UserSettings>();
  final appState = getIt<AppState>();

  ThemeMode get currentThemeMode => appState.themeMode;

  void setThemeMode(ThemeMode mode) {
    appState.updateThemeMode(mode);
    notifyListeners();
  }

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

  final _glossDb = getIt<GlossService>();

  List<GlossResource> get glossResources {
    return _glossDb.glossResources;
  }

  String? get currentGlossLangCode => _settings.glossLang;

  String? get currentGlossLangName {
    final code = currentGlossLangCode;
    if (code == null) return null;
    return glossResources
        .firstWhere(
          (r) => r.code == code,
          orElse: () => glossResources.first,
        )
        .name;
  }

  Future<void> setGlossLang(String? code) async {
    await _settings.setGlossLang(code);
    notifyListeners();
  }
}
