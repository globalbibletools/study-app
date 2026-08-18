import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gbt/ui/home/audio/audio_player_view_model.dart';
import 'package:scripture/scripture.dart';
import 'package:gbt/app_state.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_languages.dart';
import 'package:gbt/services/app_guide/app_guide_manager.dart';
import 'package:gbt/services/files/file_service.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/appbar/reference_chooser/reference_chooser.dart';
import 'package:gbt/ui/home/common/scroll_sync_controller.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';

class HomeManager {
  final currentReference = ValueNotifier<Reference>(
    const Reference(bookId: 1, chapter: 1, verse: 1),
  );
  final isSinglePanelNotifier = ValueNotifier(true);
  final textParagraphNotifier = ValueNotifier<List<UsfmLine>>([]);
  final syncController = ScrollSyncController();
  final panelAnchorNotifier = ValueNotifier<Reference>(
    const Reference(bookId: 1, chapter: 1, verse: 1),
  );
  final settingsVersionNotifier = ValueNotifier<int>(0);

  final chooserKey = GlobalKey<ReferenceChooserState>();

  // 2. State for the Keypad visibility and enabled keys
  final inputModeNotifier = ValueNotifier<ReferenceInputMode>(
    ReferenceInputMode.none,
  );
  final enabledDigitsNotifier = ValueNotifier<Set<int>>({
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
  });

  final audioPlayerViewModel = AudioPlayerViewModel();
  final _bibleService = getIt<BibleService>();
  final _settings = getIt<UserSettings>();
  final _downloadService = getIt<DownloadService>();
  final _assetService = getIt<RemoteAssetService>();
  final _fileService = getIt<FileService>();
  final readingSessionManager = getIt<ReadingSessionManager>();
  final appGuideManager = getIt<AppGuideManager>();

  int? _lastSavedBook;
  int? _lastSavedChapter;

  int get currentBookId => currentReference.value.bookId;
  int get currentChapter => currentReference.value.chapter;
  int get currentVerse => currentReference.value.verse;

  Future<void> init() async {
    final (bookId, chapter) = _settings.currentBookChapter;
    _lastSavedBook = bookId;
    _lastSavedChapter = chapter;

    final ref = Reference(bookId: bookId, chapter: chapter, verse: 1);
    currentReference.value = ref;
    panelAnchorNotifier.value = ref;

    syncController.addListener(_onSyncUpdate);
    // audioManager.setSyncController(syncController);

    syncController.clearActiveSource();
    syncController.updatePosition('manager', bookId, chapter, 0.0, verse: 1);
  }

  void _onSyncUpdate() {
    final newBook = syncController.bookId;
    final newChapter = syncController.chapter;
    if (newBook == null || newChapter == null) return;
    final newVerse = syncController.verse ?? 1;

    // Updates the AppBar, but NOT panelAnchorNotifier
    updateReference(newBook, newChapter, newVerse);
    saveBookAndChapter(newBook, newChapter);
  }

  Future<void> checkOnboarding(BuildContext context) async {
    final settings = getIt<UserSettings>();
    if (settings.hasSetLocale) return;

    final systemLocale = View.of(context).platformDispatcher.locale;
    final isSupported = AppLanguages.supported.any(
      (l) => l.code == systemLocale.languageCode,
    );

    await settings.setLocale(isSupported ? systemLocale.languageCode : 'en');

    getIt<AppState>().init();
  }

  void notifySettingsChanged() {
    settingsVersionNotifier.value++;
  }

  void setInputMode(ReferenceInputMode mode) {
    inputModeNotifier.value = mode;
  }

  void setEnabledDigits(Set<int> digits) {
    enabledDigitsNotifier.value = digits;
  }

  // Connects Keypad buttons to the AppBar
  void handleDigit(int digit) {
    chooserKey.currentState?.handleDigit(digit);
  }

  void handleBackspace() => chooserKey.currentState?.handleBackspace();
  void handleSubmit() => chooserKey.currentState?.handleSubmit();

  // Closes the keypad
  void resetKeypad() => chooserKey.currentState?.resetAll();

  void updateReference(int bookId, int chapter, int verse) {
    if (currentReference.value.bookId == bookId &&
        currentReference.value.chapter == chapter &&
        currentReference.value.verse == verse) {
      return;
    }
    currentReference.value = Reference(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
    );
  }

  Future<void> saveBookAndChapter(int bookId, int chapter) async {
    if (_lastSavedBook == bookId && _lastSavedChapter == chapter) return;
    _lastSavedBook = bookId;
    _lastSavedChapter = chapter;
    await _settings.setCurrentBookChapter(bookId, chapter);
  }

  void togglePanelState() {
    panelAnchorNotifier.value = currentReference.value;
    isSinglePanelNotifier.value = !isSinglePanelNotifier.value;
  }

  Future<void> toggleAudio(BuildContext context) async {
    if (audioPlayerViewModel.isVisible) {
        await audioPlayerViewModel.close();
        return;
    }

    try {
        await audioPlayerViewModel.openAt(Reference(
            bookId: currentBookId,
            chapter: currentChapter,
            verse: currentVerse,
        ));
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(content: Text(e.toString())),
        );
      }
    }

    await audioPlayerViewModel.play();
  }

  Future<void> requestText() async {
    final content = await _bibleService.getChapter(
      currentBookId,
      currentReference.value.chapter,
    );
    textParagraphNotifier.value = content;
  }

  void onBookSelected(BuildContext context, int bookId) {
    final ref = Reference(bookId: bookId, chapter: 1, verse: 1);
    audioPlayerViewModel.jumpTo(ref);
    currentReference.value = ref;
    panelAnchorNotifier.value = ref;
    syncController.clearActiveSource();
    syncController.updatePosition('manager', bookId, 1, 0.0, verse: 1);
  }

  void onChapterSelected(int chapter) {
    final ref = Reference(bookId: currentBookId, chapter: chapter, verse: 1);
    audioPlayerViewModel.jumpTo(ref);
    currentReference.value = ref;
    panelAnchorNotifier.value = ref;
    syncController.clearActiveSource();
    syncController.updatePosition(
      'manager',
      currentBookId,
      chapter,
      0.0,
      verse: 1,
    );
  }

  void dispose() {
    syncController.removeListener(_onSyncUpdate);
    syncController.dispose();
    audioPlayerViewModel.dispose();
    currentReference.dispose();
    isSinglePanelNotifier.dispose();
    textParagraphNotifier.dispose();
    settingsVersionNotifier.dispose();
    inputModeNotifier.dispose();
    enabledDigitsNotifier.dispose();
    readingSessionManager.dispose();
  }
}
