import 'package:flutter/foundation.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/settings/user_settings.dart';

class BiblePanelManager {
  final _settings = getIt<UserSettings>();

  late final fontScaleNotifier = ValueNotifier<double>(
    _settings.bibleFontScale,
  );

  double get baseFontSize => 20.0; // Standard English font size

  Future<void> saveFontScale(double scale) async {
    fontScaleNotifier.value = scale;
    await _settings.setBibleFontScale(scale);
  }

  /// Re-reads the persisted scale from UserSettings into the notifier.
  /// Call after returning from the settings screen.
  void refreshFromSettings() {
    fontScaleNotifier.value = _settings.bibleFontScale;
  }

  void dispose() {
    fontScaleNotifier.dispose();
  }
}
