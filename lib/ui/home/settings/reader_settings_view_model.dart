import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/serial_queue.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/home_manager.dart';

/// View model behind the reader settings sheet.
///
/// The sheet's section widgets (gloss language, Bible, verse layout, font
/// sizes) keep their getIt-based shape for now; this view model owns the
/// state the sheet itself renders: the parallel-Bible toggle.
class ReaderSettingsViewModel extends ChangeNotifier {
  ReaderSettingsViewModel._({
    required UserSettings settings,
    required HomeManager homeManager,
  }) : _settings = settings,
       _homeManager = homeManager;

  static Future<ReaderSettingsViewModel> create({
    UserSettings? settings,
    HomeManager? homeManager,
  }) async {
    final viewModel = ReaderSettingsViewModel._(
      settings: settings ?? getIt<UserSettings>(),
      homeManager: homeManager ?? getIt<HomeManager>(),
    );

    viewModel._parallelBibleEnabled = viewModel._settings.parallelBibleEnabled;

    return viewModel;
  }

  final UserSettings _settings;
  final HomeManager _homeManager;

  bool _parallelBibleEnabled = false;
  bool get parallelBibleEnabled => _parallelBibleEnabled;

  final _commands = SerialQueue();

  /// Applies the parallel-Bible toggle.
  ///
  /// [pickBible] is the Bible chooser dialog; the widget supplies it because
  /// dialogs need a [BuildContext]. When the toggle is turned on with no
  /// Bible selected, [HomeManager] runs it first and keeps the panel off if
  /// it reports no selection.
  Future<void> setParallelBibleEnabled(
    bool value, {
    required Future<bool> Function() pickBible,
  }) {
    return _commands.runCoalesced('parallel-bible', () async {
      await _homeManager.setParallelBibleEnabled(value, pickBible: pickBible);
      _setState(() {
        _parallelBibleEnabled = _settings.parallelBibleEnabled;
      });
    });
  }

  bool _disposed = false;

  void _setState(VoidCallback fn) {
    if (_disposed) return;
    fn();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(() async {
      await _commands.close();

      super.dispose();
    }());
  }
}
