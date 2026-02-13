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

  void dispose() {
    fontScaleNotifier.dispose();
  }
}
