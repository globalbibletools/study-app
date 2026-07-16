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

  VerseLayout get verseLayout => _settings.verseLayout;

  void setThemeMode(ThemeMode mode) {
    appState.updateThemeMode(mode);
    notifyListeners();
  }

  void setVerseLayout(VerseLayout value) {
    _settings.setVerseLayout(value);
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

  String get currentGlossLangCode => _settings.glossLang;

  String get currentGlossLangName {
    final code = currentGlossLangCode;
    return glossResources
        .firstWhere(
          (r) => r.code == code,
          orElse: () => glossResources.first,
        )
        .name;
  }

  Future<void> setGlossLang(String code) async {
    await _settings.setGlossLang(code);
    notifyListeners();
  }

  double get minFontSize => 10;
  double get maxFontSize => 60;
  int get fontSizeDivisions => 50;

  double get hebrewTextSize =>
      (_settings.baseFontSize * _settings.hebrewFontScale).roundToDouble();

  Future<void> setHebrewTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setHebrewFontScale(scale);
    notifyListeners();
  }

  double get greekTextSize =>
      (_settings.baseFontSize * _settings.greekFontScale).roundToDouble();

  Future<void> setGreekTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setGreekFontScale(scale);
    notifyListeners();
  }

  double get bibleTextSize =>
      (_settings.baseFontSize * _settings.bibleFontScale).roundToDouble();

  Future<void> setBibleTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setBibleFontScale(scale);
    notifyListeners();
  }

  double get lexiconTextSize =>
      (_settings.baseFontSize * _settings.wordDetailsFontScale).roundToDouble();

  Future<void> setLexiconTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setWordDetailsFontScale(scale);
    notifyListeners();
  }
}
