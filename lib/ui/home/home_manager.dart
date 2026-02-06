import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:scripture/scripture.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/services/audio/audio_url_helper.dart';
import 'package:studyapp/services/bible/bible_database.dart';
import 'package:studyapp/services/download/cancel_token.dart';
import 'package:studyapp/services/download/download.dart';
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';
import 'package:studyapp/ui/home/audio/audio_logic.dart';
import 'package:studyapp/ui/home/audio/audio_manager.dart';
import 'package:studyapp/ui/home/common/scroll_sync_controller.dart';

class HomeManager {
  final currentBookNotifier = ValueNotifier<String>('');
  final currentChapterNotifier = ValueNotifier<int>(1);
  final isSinglePanelNotifier = ValueNotifier(true);
  final textParagraphNotifier = ValueNotifier<List<UsfmLine>>([]);
  final currentTranslationNotifier = ValueNotifier<String>('BSB');

  final audioManager = AudioManager();
  final _bibleDb = getIt<BibleDatabase>();
  final _settings = getIt<UserSettings>();
  final _downloadService = getIt<DownloadService>();

  late int _currentBookId;
  int get currentBookId => _currentBookId;

  Future<void> init(BuildContext context) async {
    final (bookId, chapter) = _settings.currentBookChapter;
    _currentBookId = bookId;
    _updateUiForBook(context, bookId, chapter);
  }

  void _updateUiForBook(BuildContext context, int bookId, int chapter) {
    _currentBookId = bookId;
    currentBookNotifier.value = bookNameFromId(context, bookId);
    currentChapterNotifier.value = chapter;
  }

  void setSyncController(ScrollSyncController controller) {
    audioManager.setSyncController(controller);
  }

  (int, int) getInitialBookAndChapter() {
    return _settings.currentBookChapter;
  }

  Future<void> saveBookAndChapter(int bookId, int chapter) async {
    _currentBookId = bookId;
    await _settings.setCurrentBookChapter(bookId, chapter);
  }

  void togglePanelState() {
    isSinglePanelNotifier.value = !isSinglePanelNotifier.value;
  }

  void changeTranslation(String translationId) {
    currentTranslationNotifier.value = translationId;
  }

  Future<dynamic> getAvailableTranslations() async {
    return [
      'Arabic (VDV)',
      'English (BSB)',
      'French (LSG)',
      'Portuguese (BLJ)',
      'Spanish (BLM)',
    ];
  }

  Future<void> requestText() async {
    final content = await _bibleDb.getChapter(
      _currentBookId,
      currentChapterNotifier.value,
    );
    textParagraphNotifier.value = content;
  }

  void onBookSelected(BuildContext context, int bookId) {
    audioManager.stopAndClose();
    _currentBookId = bookId;
    _updateUiForBook(context, bookId, 1);
  }

  void onChapterSelected(int chapter) {
    audioManager.stopAndClose();
    currentChapterNotifier.value = chapter;
  }

  Future<void> playAudioForCurrentChapter(
    String bookName,
    int chapter, {
    int? startVerse,
  }) async {
    await audioManager.loadAndPlay(
      _currentBookId,
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

    final url = AudioUrlHelper.getAudioUrl(
      bookId: bookId,
      chapter: chapter,
      recordingId: recordingId,
    );
    final relativePath = AudioUrlHelper.getLocalRelativePath(
      bookId: bookId,
      chapter: chapter,
      recordingId: recordingId,
    );

    await _downloadService.downloadFile(
      url: url,
      type: FileType.audio,
      relativePath: relativePath,
      cancelToken: cancelToken,
      onProgress: (p) => progressNotifier.value = p,
    );
  }

  void dispose() {
    audioManager.dispose();
    currentBookNotifier.dispose();
    currentChapterNotifier.dispose();
    isSinglePanelNotifier.dispose();
    textParagraphNotifier.dispose();
    currentTranslationNotifier.dispose();
  }
}
