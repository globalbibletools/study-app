import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:scripture/scripture.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/services/assets/remote_asset_service.dart';
import 'package:studyapp/services/bible/bible_service.dart';
import 'package:studyapp/services/download/cancel_token.dart';
import 'package:studyapp/services/download/download.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/settings/user_settings.dart';
import 'package:studyapp/ui/common/download_progress_dialog.dart';
import 'package:studyapp/ui/home/appbar/reference_chooser/reference_chooser.dart';
import 'package:studyapp/ui/home/audio/audio_logic.dart';
import 'package:studyapp/ui/home/audio/audio_manager.dart';
import 'package:studyapp/ui/home/common/scroll_sync_controller.dart';

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

  final audioManager = AudioManager();
  final _bibleService = getIt<BibleService>();
  final _settings = getIt<UserSettings>();
  final _downloadService = getIt<DownloadService>();
  final _assetService = getIt<RemoteAssetService>();

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
    audioManager.setSyncController(syncController);
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
    print("DEBUG: Manager handleDigit: $digit");
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
    print('saving book $bookId and chapter $chapter');
    _lastSavedBook = bookId;
    _lastSavedChapter = chapter;
    await _settings.setCurrentBookChapter(bookId, chapter);
  }

  void togglePanelState() {
    isSinglePanelNotifier.value = !isSinglePanelNotifier.value;
  }

  Future<void> toggleAudio(BuildContext context) async {
    // If already open, close it
    if (audioManager.isVisibleNotifier.value) {
      audioManager.stopAndClose();
      return;
    }

    final bookId = currentBookId;
    final chapter = currentChapter;
    final verse = currentVerse;

    // Check if audio is actually available for this book/chapter
    if (!AudioLogic.isAudioAvailable(bookId, chapter)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.audioNotAvailable),
          ),
        );
      }
      return;
    }

    try {
      await playAudioForCurrentChapter(
        bookNameFromId(context, bookId),
        chapter,
        startVerse: verse,
      );
    } on AudioMissingException catch (_) {
      if (context.mounted) {
        _promptDownloadAudio(context);
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _promptDownloadAudio(BuildContext context) async {
    final bookName = bookNameFromId(context, currentBookId);
    final l10n = AppLocalizations.of(context)!;

    // Capture values before async gap
    final bookIdToDownload = currentBookId;
    final chapterToDownload = currentChapter;

    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.downloadAudio),
          content: Text(l10n.audioNotDownloaded(bookName, chapterToDownload)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.download),
            ),
          ],
        );
      },
    );

    if (shouldDownload != true) return;
    if (!context.mounted) return;

    try {
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, cancelToken) {
          return downloadAudioForChapter(
            bookIdToDownload,
            chapterToDownload,
            progress,
            cancelToken,
          );
        },
      );

      if (!context.mounted) return;

      // Recursive call to play (now that it's downloaded)
      // We pass context again since we are starting a new operation
      toggleAudio(context);
    } catch (e) {
      if (!context.mounted) return;
      if (e is! DownloadCanceledException) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Download error: $e")));
      }
    }
  }

  Future<void> requestText() async {
    final content = await _bibleService.getChapter(
      currentBookId,
      currentReference.value.chapter,
    );
    textParagraphNotifier.value = content;
  }

  void onBookSelected(BuildContext context, int bookId) {
    audioManager.stopAndClose();
    final ref = Reference(bookId: bookId, chapter: 1, verse: 1);
    currentReference.value = ref;
    panelAnchorNotifier.value = ref;
  }

  void onChapterSelected(int chapter) {
    audioManager.stopAndClose();
    final ref = Reference(bookId: currentBookId, chapter: chapter, verse: 1);
    currentReference.value = ref;
    panelAnchorNotifier.value = ref;
  }

  Future<void> playAudioForCurrentChapter(
    String bookName,
    int chapter, {
    int? startVerse,
  }) async {
    await audioManager.loadAndPlay(
      currentBookId,
      chapter,
      bookName,
      startVerse: startVerse,
    );
  }

  /// Returns a Future that completes when download is done.
  /// Used by the ProgressDialog.
  Future<void> downloadAudioForChapter(
    int bookId,
    int chapter,
    ValueNotifier<double> progressNotifier,
    CancelToken cancelToken,
  ) async {
    final recordingId = AudioLogic.getRecordingId(
      bookId,
      audioManager.audioSourceNotifier.value,
    );
    final asset = _assetService.getAudioChapterAsset(
      bookId: bookId,
      chapter: chapter,
      recordingId: recordingId,
    );
    if (asset == null) return;
    await _downloadService.downloadAsset(
      asset: asset,
      cancelToken: cancelToken,
      onProgress: (p) => progressNotifier.value = p,
    );
  }

  void dispose() {
    syncController.removeListener(_onSyncUpdate);
    syncController.dispose();
    audioManager.dispose();
    currentReference.dispose();
    isSinglePanelNotifier.dispose();
    textParagraphNotifier.dispose();
    settingsVersionNotifier.dispose();
    inputModeNotifier.dispose();
    enabledDigitsNotifier.dispose();
  }
}
