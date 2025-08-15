import 'package:flutter/foundation.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class HebrewGreekPanelManager {
  final _settings = getIt<UserSettings>();

  late final fontScaleNotifier = ValueNotifier<double>(_settings.fontScale);

  double get baseFontSize => _settings.baseFontSize;

  Future<void> saveFontScale(double scale) async {
    await _settings.setFontScale(scale);
  }

  void dispose() {
    fontScaleNotifier.dispose();
  }
}
