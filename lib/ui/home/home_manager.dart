import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:scripture/scripture.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/services/assets/remote_asset_service.dart';
import 'package:studyapp/services/bible/bible_service.dart';
import 'package:studyapp/services/download/cancel_token.dart';
import 'package:studyapp/services/download/download.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/settings/user_settings.dart';
import 'package:studyapp/ui/home/audio/audio_logic.dart';
import 'package:studyapp/ui/home/audio/audio_manager.dart';
import 'package:studyapp/ui/home/common/scroll_sync_controller.dart';

class HomeManager {
  final currentReference = ValueNotifier<Reference>(
    const Reference(bookId: 1, chapter: 1, verse: 1),
  );
  final isSinglePanelNotifier = ValueNotifier(true);
  final textParagraphNotifier = ValueNotifier<List<UsfmLine>>([]);

  final audioManager = AudioManager();
  final _bibleService = getIt<BibleService>();
  final _settings = getIt<UserSettings>();
  final _downloadService = getIt<DownloadService>();
  final _assetService = getIt<RemoteAssetService>();

  int get currentBookId => currentReference.value.bookId;
  int get currentChapter => currentReference.value.chapter;
  int get currentVerse => currentReference.value.verse;

  Future<void> init() async {
    final (bookId, chapter) = _settings.currentBookChapter;
    currentReference.value = Reference(
      bookId: bookId,
      chapter: chapter,
      verse: 1,
    );
  }

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

  void setSyncController(ScrollSyncController controller) {
    audioManager.setSyncController(controller);
  }

  // (int, int) getInitialBookAndChapter() {
  //   return _settings.currentBookChapter;
  // }

  Future<void> saveBookAndChapter(int bookId, int chapter) async {
    if (bookId == currentReference.value.bookId &&
        chapter == currentReference.value.chapter) {
      return;
    }
    print('saving book $bookId and chapter $chapter');
    await _settings.setCurrentBookChapter(bookId, chapter);
  }

  void togglePanelState() {
    isSinglePanelNotifier.value = !isSinglePanelNotifier.value;
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
    currentReference.value = Reference(bookId: bookId, chapter: 1, verse: 1);
  }

  void onChapterSelected(int chapter) {
    audioManager.stopAndClose();
    currentReference.value = Reference(
      bookId: currentBookId,
      chapter: chapter,
      verse: 1,
    );
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
    audioManager.dispose();
    currentReference.dispose();
    isSinglePanelNotifier.dispose();
    textParagraphNotifier.dispose();
  }
}
