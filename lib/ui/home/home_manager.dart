import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:scripture/scripture.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/services/audio/audio_database.dart';
import 'package:studyapp/services/audio/audio_player_handler.dart';
import 'package:studyapp/services/audio/audio_timing.dart';
import 'package:studyapp/services/audio/audio_url_helper.dart';
import 'package:studyapp/services/bible/bible_database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';
import 'package:studyapp/ui/home/common/scroll_sync_controller.dart';

enum AudioRepeatMode { none, chapter, verse }

enum AudioSourceType { heb, rdb }

class HomeManager {
  final currentBookNotifier = ValueNotifier<String>('');
  final currentChapterNotifier = ValueNotifier<int>(1);
  final isSinglePanelNotifier = ValueNotifier(true);
  final textParagraphNotifier = ValueNotifier<List<UsfmLine>>([]);
  final isAudioVisibleNotifier = ValueNotifier<bool>(false);
  final playbackSpeedNotifier = ValueNotifier<double>(1.0);
  final repeatModeNotifier = ValueNotifier<AudioRepeatMode>(
    AudioRepeatMode.chapter,
  );
  final audioSourceNotifier = ValueNotifier<AudioSourceType>(
    AudioSourceType.heb,
  );

  final audioHandler = AudioPlayerHandler();

  final _bibleDb = getIt<BibleDatabase>();
  final _audioDb = getIt<AudioDatabase>();
  final _settings = getIt<UserSettings>();
  late int _currentBookId;

  // We need access to the SyncController to trigger jumps.
  // Ideally, pass this in init, or set it via setter if created in UI.
  ScrollSyncController? _syncController;
  StreamSubscription? _positionSubscription;
  List<AudioTiming> _currentTimings = [];
  int _lastSyncedVerse = -1;

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
    _syncController = controller;
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
    closeAudioPlayer();
    _currentBookId = bookId;
    _updateUiForBook(context, bookId, 1);
  }

  void onChapterSelected(int chapter) {
    closeAudioPlayer();
    currentChapterNotifier.value = chapter;
  }

  Future<void> setAudioSource(
    AudioSourceType source,
    BuildContext context,
  ) async {
    if (audioSourceNotifier.value == source) return;

    audioSourceNotifier.value = source;
    // Reload audio with new source
    if (isAudioVisibleNotifier.value) {
      await playAudioForCurrentChapter(
        currentBookNotifier.value,
        currentChapterNotifier.value,
      );
    }
  }

  Future<void> playAudioForCurrentChapter(String bookName, int chapter) async {
    isAudioVisibleNotifier.value = true;
    final bookId = _currentBookId;

    String recordingId = audioSourceNotifier.value == AudioSourceType.heb
        ? 'HEB'
        : 'RDB';

    final url = AudioUrlHelper.getAudioUrl(
      bookId: bookId,
      chapter: chapter,
      recordingId: recordingId,
    );

    _currentTimings = await _audioDb.getTimingsForChapter(
      bookId,
      chapter,
      recordingId,
    );
    _lastSyncedVerse = -1;

    await audioHandler.setUrl(
      url,
      title: "$bookName $chapter",
      subtitle: bookName,
    );

    // Apply current speed
    await audioHandler.setSpeed(playbackSpeedNotifier.value);

    audioHandler.play();
    _startSyncListener();
  }

  void _startSyncListener() {
    _positionSubscription?.cancel();
    _positionSubscription = audioHandler.positionDataStream.listen((
      positionData,
    ) {
      if (_currentTimings.isEmpty) return;

      final currentSeconds = positionData.position.inMilliseconds / 1000.0;

      // --- REPEAT VERSE LOGIC ---
      if (repeatModeNotifier.value == AudioRepeatMode.verse) {
        // Find current verse bounds
        AudioTiming? currentMatch;
        for (var t in _currentTimings) {
          if (t.verseNumber == _lastSyncedVerse) {
            // Use the last synced verse as truth
            currentMatch = t;
            break;
          }
        }

        // If we have passed the end of the verse, loop back
        if (currentMatch != null && currentSeconds >= currentMatch.end - 0.2) {
          // Seek back to start of this verse
          audioHandler.seek(
            Duration(milliseconds: (currentMatch.start * 1000).toInt()),
          );
          return; // Skip the rest of the logic this tick
        }
      }

      // Find the verse corresponding to current time
      // We look for: start <= time < end
      // Optimization: We could track index, but list size (~30-150 items) is small enough for iteration
      AudioTiming? match;
      try {
        match = _currentTimings.firstWhere(
          (t) => currentSeconds >= t.start && currentSeconds < t.end,
        );
      } catch (e) {
        // No match (silence between verses), clear highlight
        _syncController?.setHighlightedVerse(null);
        return;
      }

      final verseNum = match.verseNumber;

      // Highlight the text
      _syncController?.setHighlightedVerse(verseNum);

      // Scroll to it
      if (verseNum != _lastSyncedVerse) {
        _lastSyncedVerse = verseNum;
        _syncController?.jumpToVerse(verseNum);
      }
    });
  }

  void setPlaybackSpeed(double speed) {
    playbackSpeedNotifier.value = speed;
    audioHandler.setSpeed(speed);
  }

  void setRepeatMode(AudioRepeatMode mode) {
    repeatModeNotifier.value = mode;
    // If you want "None" to stop at end of track vs "Chapter" to loop track:
    // audioHandler.setLoopMode(mode == AudioRepeatMode.chapter ? LoopMode.one : LoopMode.off);
  }

  void skipToNextVerse() {
    if (_currentTimings.isEmpty) return;

    final currentPos = audioHandler.position.inMilliseconds / 1000.0;

    // Find the current verse index
    int currentIndex = -1;
    for (int i = 0; i < _currentTimings.length; i++) {
      if (currentPos >= _currentTimings[i].start &&
          currentPos < _currentTimings[i].end) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex != -1) {
      // We are inside a verse. Jump to the next one.
      if (currentIndex + 1 < _currentTimings.length) {
        final nextStart = _currentTimings[currentIndex + 1].start;
        audioHandler.seek(Duration(milliseconds: (nextStart * 1000).toInt()));
      }
    } else {
      // We are in a gap (silence). Find the next verse that starts after now.
      for (final t in _currentTimings) {
        if (t.start > currentPos) {
          audioHandler.seek(Duration(milliseconds: (t.start * 1000).toInt()));
          break;
        }
      }
    }
  }

  void skipToPreviousVerse() {
    if (_currentTimings.isEmpty) return;

    final currentPos = audioHandler.position.inMilliseconds / 1000.0;

    // Find current verse index
    int currentIndex = -1;
    for (int i = 0; i < _currentTimings.length; i++) {
      if (currentPos >= _currentTimings[i].start &&
          currentPos < _currentTimings[i].end) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex != -1) {
      // We are inside a verse.
      if (currentIndex > 0) {
        // Jump to the start of the previous verse
        final prevStart = _currentTimings[currentIndex - 1].start;
        audioHandler.seek(Duration(milliseconds: (prevStart * 1000).toInt()));
      } else {
        // We are at the first verse, jump to 0
        audioHandler.seek(Duration.zero);
      }
    } else {
      // We are in a gap. Find the last verse that ended before now.
      for (int i = _currentTimings.length - 1; i >= 0; i--) {
        if (_currentTimings[i].end <= currentPos) {
          final targetStart = _currentTimings[i].start;
          audioHandler.seek(
            Duration(milliseconds: (targetStart * 1000).toInt()),
          );
          break;
        }
      }
    }
  }

  void closeAudioPlayer() {
    if (isAudioVisibleNotifier.value) {
      isAudioVisibleNotifier.value = false;
      audioHandler.stop();
      _positionSubscription?.cancel();
      _currentTimings = [];
      _syncController?.setHighlightedVerse(null);
    }
  }

  void dispose() {
    audioHandler.dispose();
  }
}
