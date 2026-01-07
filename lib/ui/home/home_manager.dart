import 'package:flutter/widgets.dart';
import 'package:scripture/scripture.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/services/audio/audio_player_handler.dart';
import 'package:studyapp/services/bible/bible_database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class HomeManager {
  final currentBookNotifier = ValueNotifier<String>('');
  final currentChapterNotifier = ValueNotifier<int>(1);
  final isSinglePanelNotifier = ValueNotifier(true);
  final textParagraphNotifier = ValueNotifier<List<UsfmLine>>([]);
  final isAudioVisibleNotifier = ValueNotifier<bool>(false);

  final audioHandler = AudioPlayerHandler();

  final _bibleDb = getIt<BibleDatabase>();
  final _settings = getIt<UserSettings>();
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

  (int, int) getInitialBookAndChapter() {
    return _settings.currentBookChapter;
  }

  Future<void> saveBookAndChapter(int bookId, int chapter) async {
    await _settings.setCurrentBookChapter(bookId, chapter);
  }

  void togglePanelState() {
    isSinglePanelNotifier.value = !isSinglePanelNotifier.value;
  }

  Future<void> requestText() async {
    final content = await _bibleDb.getChapter(
      _currentBookId,
      currentChapterNotifier.value,
    );
    textParagraphNotifier.value = content;
  }

  void onBookSelected(BuildContext context, int bookId) {
    _currentBookId = bookId;
    _updateUiForBook(context, bookId, 1);
  }

  void onChapterSelected(int chapter) {
    currentChapterNotifier.value = chapter;
  }

  Future<void> playAudioForCurrentChapter(String bookName, int chapter) async {
    // 1. Show the player UI
    isAudioVisibleNotifier.value = true;

    // 2. Generate or fetch URL
    // TODO: Replace this with your actual logic to get the URL for Book/Chapter
    // For demo, we use a sample MP3
    const String sampleUrl =
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";

    // 3. Play
    await audioHandler.playUrl(
      sampleUrl,
      title: "Chapter $chapter",
      subtitle: bookName,
    );
  }

  void closeAudioPlayer() {
    isAudioVisibleNotifier.value = false;
    // Optional: audioHandler.stop(); // If you want closing UI to stop playback
  }

  void dispose() {
    audioHandler.dispose();
  }
}
