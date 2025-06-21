import 'package:flutter/material.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class AppState extends ChangeNotifier {
  final _settings = getIt<UserSettings>();

  void init() {
    _locale = _settings.locale;
    notifyListeners();
  }

  /// The user's preferred locale.
  ///
  /// A null value means we should use the system default locale.
  Locale? get locale => _locale;
  Locale? _locale;

  set locale(Locale? locale) {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
  }
}
