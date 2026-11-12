import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gbt/ui/home/audio/audio_player_view_model.dart';
import 'package:scripture/scripture.dart';
import 'package:gbt/app_state.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_languages.dart';
import 'package:gbt/services/app_guide/app_guide_manager.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/common/bible_chooser.dart';
import 'package:gbt/ui/home/appbar/reference_chooser/reference_chooser.dart';
import 'package:gbt/ui/home/common/scroll_sync_controller.dart';
import 'package:gbt/ui/home/reading_plan/reading_session_view_model.dart';
import 'package:gbt/ui/home/word_details_dialog/dialog_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/similar_verses/similar_verses_page.dart';

class OccurrenceSearchContext {
  final WordDetails word;
  final String? wordId;
  final SearchType searchType;
  final Reference anchorReference;
  final double scrollOffset;

  const OccurrenceSearchContext({
    required this.word,
    this.wordId,
    required this.searchType,
    required this.anchorReference,
    this.scrollOffset = 0.0,
  });
}

class WordStudySession {
  final String wordId;
  final bool isRtl;
  final Reference originalReference;
  final isOverlayVisibleNotifier = ValueNotifier<bool>(true);
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  WordStudySession({
    required this.wordId,
    required this.isRtl,
    required this.originalReference,
    bool isOverlayVisible = true,
  }) {
    isOverlayVisibleNotifier.value = isOverlayVisible;
  }

  bool get isOverlayVisible => isOverlayVisibleNotifier.value;
  set isOverlayVisible(bool value) => isOverlayVisibleNotifier.value = value;

  void dispose() {
    isOverlayVisibleNotifier.dispose();
  }
}

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
  final searchContextNotifier = ValueNotifier<OccurrenceSearchContext?>(null);
  final wordStudySessionNotifier = ValueNotifier<WordStudySession?>(null);
  final flashedWordIdNotifier = ValueNotifier<String?>(null);

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
  final readingSessionViewModel = getIt<ReadingSessionViewModel>();
  final appGuideManager = getIt<AppGuideManager>();

  int? _lastSavedBook;
  int? _lastSavedChapter;

  HomeManager() {
    _bibleService.addBibleResourceChangeListener(_onBibleResourceChanged);
    syncController.listenToAudioReference(audioPlayerViewModel.reference);
  }

  Future<void> _onBibleResourceChanged(String bibleId) async {
    if (_settings.currentBible != bibleId) return;

    if (!await _bibleService.bibleExists(bibleId)) {
      await _settings.setCurrentBible(null);
    }

    notifySettingsChanged();
  }

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
    // No Bible selected: the Bible panel has nothing to show, so close it.
    if (_settings.currentBible == null) {
      isSinglePanelNotifier.value = true;
    }
    settingsVersionNotifier.value++;
  }

  void setInputMode(ReferenceInputMode mode) {
    inputModeNotifier.value = mode;
  }

  void closeBiblePanel() {
    isSinglePanelNotifier.value = true;
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

  Future<void> togglePanelState(BuildContext context) async {
    // Opening the Bible panel requires a selected Bible. If none is selected,
    // prompt the user to pick one first instead of opening an empty panel.
    if (isSinglePanelNotifier.value && _settings.currentBible == null) {
      final chosen = await chooseBible(context);
      if (!chosen) return;
    }

    panelAnchorNotifier.value = currentReference.value;
    isSinglePanelNotifier.value = !isSinglePanelNotifier.value;
  }

  Future<void> toggleAudio(BuildContext context) async {
    if (audioPlayerViewModel.isVisible) {
      await audioPlayerViewModel.close();
      return;
    }

    try {
      await audioPlayerViewModel.openAt(
        Reference(
          bookId: currentBookId,
          chapter: currentChapter,
          verse: currentVerse,
        ),
      );
    } catch (e, stack) {
      debugPrint("Audio Error: $e");
      debugPrintStack(stackTrace: stack);
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
    dismissWordStudySession(keepCurrentLocation: true);
    clearSearchContext();
    final ref = Reference(bookId: bookId, chapter: 1, verse: 1);
    audioPlayerViewModel.pause();
    audioPlayerViewModel.jumpTo(ref);
    currentReference.value = ref;
    panelAnchorNotifier.value = ref;
    syncController.clearActiveSource();
    syncController.updatePosition('manager', bookId, 1, 0.0, verse: 1);
  }

  void onChapterSelected(int chapter) {
    dismissWordStudySession(keepCurrentLocation: true);
    clearSearchContext();
    final ref = Reference(bookId: currentBookId, chapter: chapter, verse: 1);
    audioPlayerViewModel.pause();
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

  /// Starts a new word study session, preserving the original reading reference.
  void startWordStudy({required String wordId, required bool isRtl}) {
    if (wordStudySessionNotifier.value != null) {
      dismissWordStudySession(keepCurrentLocation: true);
    }
    wordStudySessionNotifier.value = WordStudySession(
      wordId: wordId,
      isRtl: isRtl,
      originalReference: currentReference.value,
    );
  }

  /// Toggles visibility of the word study offstage overlay layer.
  void setWordStudyOverlayVisible(bool visible) {
    final session = wordStudySessionNotifier.value;
    if (session != null) {
      session.isOverlayVisible = visible;
    }
  }

  /// Ends the word study session and cleans up resources.
  ///
  /// If [keepCurrentLocation] is false, restores the reader to the original
  /// reference where the word was initially long-pressed.
  /// If true (e.g. user tapped 'x' on return pill or navigated explicitly),
  /// keeps the reader at its current location and persists it to user settings.
  void dismissWordStudySession({required bool keepCurrentLocation}) {
    final session = wordStudySessionNotifier.value;
    if (session == null) return;

    if (!keepCurrentLocation) {
      final wordIdToFlash = session.wordId;
      final ref = session.originalReference;
      currentReference.value = Reference(
        bookId: ref.bookId,
        chapter: ref.chapter,
        verse: ref.verse,
      );
      panelAnchorNotifier.value = Reference(
        bookId: ref.bookId,
        chapter: ref.chapter,
        verse: ref.verse,
      );
      saveBookAndChapter(ref.bookId, ref.chapter);
      syncController.clearActiveSource();
      syncController.jumpToVerse(ref.bookId, ref.chapter, ref.verse);
      flashWord(wordIdToFlash);
    } else {
      final current = currentReference.value;
      saveBookAndChapter(current.bookId, current.chapter);
    }

    session.dispose();
    wordStudySessionNotifier.value = null;
    searchContextNotifier.value = null;
  }

  /// Sets the active search context, navigates the reader to the context verse,
  /// and mounts the floating return pill.
  void jumpToContextReference(OccurrenceSearchContext context) {
    searchContextNotifier.value = context;
    final ref = context.anchorReference;

    currentReference.value = Reference(
      bookId: ref.bookId,
      chapter: ref.chapter,
      verse: ref.verse,
    );
    panelAnchorNotifier.value = Reference(
      bookId: ref.bookId,
      chapter: ref.chapter,
      verse: ref.verse,
    );

    // Note: Do not saveBookAndChapter here as this is a temporary preview!

    syncController.clearActiveSource();
    syncController.jumpToVerse(ref.bookId, ref.chapter, ref.verse);
    flashVerse(ref);
  }

  Timer? _flashTimer;
  Timer? _wordFlashTimer;

  /// Flashes the highlight for a given verse reference for 1.5 seconds.
  void flashVerse(Reference ref) {
    _flashTimer?.cancel();
    audioPlayerViewModel.reference.value = ref;
    _flashTimer = Timer(const Duration(milliseconds: 1500), () {
      if (audioPlayerViewModel.playbackState != AudioPlaybackState.playing) {
        audioPlayerViewModel.reference.value = null;
      }
    });
  }

  /// Flashes the highlight for a given word ID for 1.5 seconds.
  void flashWord(String wordId) {
    _wordFlashTimer?.cancel();
    flashedWordIdNotifier.value = wordId;
    _wordFlashTimer = Timer(const Duration(milliseconds: 1500), () {
      flashedWordIdNotifier.value = null;
    });
  }

  /// Clears the active search context and unmounts the floating return pill.
  void clearSearchContext() {
    searchContextNotifier.value = null;
  }

  void dispose() {
    _flashTimer?.cancel();
    _wordFlashTimer?.cancel();
    dismissWordStudySession(keepCurrentLocation: true);
    _bibleService.removeBibleResourceChangeListener(_onBibleResourceChanged);

    syncController.removeListener(_onSyncUpdate);
    syncController.dispose();
    audioPlayerViewModel.dispose();
    currentReference.dispose();
    isSinglePanelNotifier.dispose();
    textParagraphNotifier.dispose();
    settingsVersionNotifier.dispose();
    inputModeNotifier.dispose();
    enabledDigitsNotifier.dispose();
    readingSessionViewModel.dispose();
    flashedWordIdNotifier.dispose();
    wordStudySessionNotifier.dispose();
    searchContextNotifier.dispose();
  }
}
