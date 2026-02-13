import 'package:flutter/foundation.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/settings/user_settings.dart';

class HebrewGreekPanelManager {
  final _settings = getIt<UserSettings>();

  // Notifiers for both languages
  late final hebrewScaleNotifier = ValueNotifier<double>(
    _settings.hebrewFontScale,
  );
  late final greekScaleNotifier = ValueNotifier<double>(
    _settings.greekFontScale,
  );

  // Track the book currently in view
  int currentBookId = 1;

  double get baseFontSize => _settings.baseFontSize;
  bool isHebrew(int bookId) => bookId <= 39;

  // Decide which notifier to update based on the book in view
  void handleZoom(double newScale) {
    if (isHebrew(currentBookId)) {
      hebrewScaleNotifier.value = newScale;
      _settings.setHebrewFontScale(newScale);
    } else {
      greekScaleNotifier.value = newScale;
      _settings.setGreekFontScale(newScale);
    }
  }

  void dispose() {
    hebrewScaleNotifier.dispose();
    greekScaleNotifier.dispose();
  }
}
