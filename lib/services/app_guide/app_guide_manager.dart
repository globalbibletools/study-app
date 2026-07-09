import 'package:flutter/material.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

class AppGuideManager {
  final _settings = getIt<UserSettings>();
  final _rsmanager = getIt<ReadingSessionManager>();

  final checkBoxSpotlightRect = ValueNotifier<Rect?>(null);
  final readingSessionButtonSpotlightRect = ValueNotifier<Rect?>(null);
  final readingCheckboxGuideDismissedNotifier = ValueNotifier<bool>(false);
  final readingSessionGuideDismissedNotifier = ValueNotifier<bool>(false);

  bool get shouldShowReadingSessionGuide {
    return !_rsmanager.readingModeNotifier.value &&
        !_settings.hasSeenReadingSessionGuide &&
        !readingSessionGuideDismissedNotifier.value;
  }

  bool get shouldShowReadingCheckboxGuide {
    return _rsmanager.readingModeNotifier.value &&
        _settings.hasSeenReadingSessionGuide &&
        !_settings.hasSeenReadingCheckboxGuide &&
        !readingCheckboxGuideDismissedNotifier.value;
  }

  Future<void> dismissReadingCheckboxGuide() async {
    if (readingCheckboxGuideDismissedNotifier.value) return;
    readingCheckboxGuideDismissedNotifier.value = true;
    await _settings.setHasSeenReadingCheckboxGuide(true);
  }

  Future<void> dismissReadingSessionGuide() async {
    if (readingSessionGuideDismissedNotifier.value) return;
    readingSessionGuideDismissedNotifier.value = true;
    await _settings.setHasSeenReadingSessionGuide(true);
  }

  bool anyGuideShown() {
    return shouldShowReadingSessionGuide || shouldShowReadingCheckboxGuide;
  }

  void dispose() {
    readingCheckboxGuideDismissedNotifier.dispose();
    readingSessionGuideDismissedNotifier.dispose();
  }
}
