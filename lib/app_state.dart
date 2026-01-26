import 'package:flutter/material.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class AppState extends ChangeNotifier {
  final _settings = getIt<UserSettings>();

  void init() {
    _locale = _settings.locale;
    _loadThemeMode();
    notifyListeners();
  }

  Locale? get locale => _locale;
  Locale? _locale;

  set locale(Locale? locale) {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void _loadThemeMode() {
    final mode = _settings.themeMode;
    if (mode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (mode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
  }

  void updateThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;

    // Save to settings
    String? value;
    if (mode == ThemeMode.light) value = 'light';
    if (mode == ThemeMode.dark) value = 'dark';
    _settings.setThemeMode(value);

    notifyListeners();
  }
}
