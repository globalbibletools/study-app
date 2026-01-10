import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:studyapp/services/audio/audio_database.dart';
import 'package:studyapp/services/audio/audio_player_handler.dart';
import 'package:studyapp/services/audio/audio_timing.dart';
import 'package:studyapp/services/audio/audio_url_helper.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/ui/home/common/scroll_sync_controller.dart';

enum AudioRepeatMode { none, chapter, verse }

enum AudioSourceType { heb, rdb }

class AudioManager {
  final AudioPlayerHandler audioHandler = AudioPlayerHandler();
  final _audioDb = getIt<AudioDatabase>();

  // --- State Notifiers ---
  final isVisibleNotifier = ValueNotifier<bool>(false);
  final playbackSpeedNotifier = ValueNotifier<double>(1.0);
  final repeatModeNotifier = ValueNotifier<AudioRepeatMode>(
    AudioRepeatMode.chapter,
  );
  final audioSourceNotifier = ValueNotifier<AudioSourceType>(
    AudioSourceType.heb,
  );

  // --- Internal State ---
  ScrollSyncController? _syncController;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  List<AudioTiming> _currentTimings = [];
  int _lastSyncedVerse = -1;

  // Track what is currently playing to allow reloading on source change
  int? _loadedBookId;
  int? _loadedChapter;
  String? _loadedBookName;

  void setSyncController(ScrollSyncController controller) {
    _syncController = controller;
  }

  Future<void> loadAndPlay(int bookId, int chapter, String bookName) async {
    // Save state for reloading
    _loadedBookId = bookId;
    _loadedChapter = chapter;
    _loadedBookName = bookName;

    isVisibleNotifier.value = true;

    final recordingId = audioSourceNotifier.value == AudioSourceType.heb
        ? 'HEB'
        : 'RDB';

    final url = AudioUrlHelper.getAudioUrl(
      bookId: bookId,
      chapter: chapter,
      recordingId: recordingId,
    );

    // Fetch timings
    _currentTimings = await _audioDb.getTimingsForChapter(
      bookId,
      chapter,
      recordingId,
    );

    // --- FIX: Sanitize bad data for the last verse ---
    if (_currentTimings.isNotEmpty) {
      final last = _currentTimings.last;

      // If the end time is smaller than the start time (e.g. 0.324 < 353.277)
      // We assume it means "play until the end".
      // We set the end time to a very large number (e.g. 10 hours).
      if (last.end <= last.start) {
        _currentTimings.removeLast();
        _currentTimings.add(
          AudioTiming(
            verseId: last.verseId,
            start: last.start,
            end: 36000.0, // Arbitrary large number (10 hours)
          ),
        );
      }
    }

    _lastSyncedVerse = -1;

    // Initialize Player
    await audioHandler.setUrl(
      url,
      title: "$bookName $chapter",
      subtitle: bookName,
    );

    await audioHandler.setSpeed(playbackSpeedNotifier.value);
    _startSyncListener();
    audioHandler.play();
  }

  void _startSyncListener() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();

    // Handle End of Chapter
    _playerStateSubscription = audioHandler.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // _isChapterFinished = true; // Block highlighting

        // Clear UI Highlight
        _syncController?.setHighlightedVerse(null);
        _lastSyncedVerse = -1;

        // Reset Player (Pause & Rewind)
        audioHandler.pause();
        audioHandler.seek(Duration.zero);
      }
    });

    _positionSubscription = audioHandler.positionDataStream.listen((
      positionData,
    ) {
      if (_currentTimings.isEmpty) return;

      final currentSeconds = positionData.position.inMilliseconds / 1000.0;

      // --- REPEAT VERSE LOGIC ---
      if (repeatModeNotifier.value == AudioRepeatMode.verse) {
        AudioTiming? currentMatch;
        // Find the timing object for the verse we are supposedly in
        for (var t in _currentTimings) {
          if (t.verseNumber == _lastSyncedVerse) {
            currentMatch = t;
            break;
          }
        }

        // If valid and we passed the end, loop back
        if (currentMatch != null && currentSeconds >= currentMatch.end - 0.2) {
          audioHandler.seek(
            Duration(milliseconds: (currentMatch.start * 1000).toInt()),
          );
          return;
        }
      }
      // ---------------------------

      // Find current verse
      AudioTiming? match;
      try {
        match = _currentTimings.firstWhere(
          (t) => currentSeconds >= t.start && currentSeconds < t.end,
        );
      } catch (e) {
        _syncController?.setHighlightedVerse(null);
        return;
      }

      final verseNum = match.verseNumber;
      _syncController?.setHighlightedVerse(verseNum);

      if (verseNum != _lastSyncedVerse) {
        _lastSyncedVerse = verseNum;
        _syncController?.jumpToVerse(verseNum);
      }
    });
  }

  // --- Controls ---

  void stopAndClose() {
    if (isVisibleNotifier.value) {
      isVisibleNotifier.value = false;
      audioHandler.stop();
      _positionSubscription?.cancel();
      _currentTimings = [];
      _syncController?.setHighlightedVerse(null);
      _loadedBookId = null;
    }
  }

  void skipToNextVerse() {
    if (_currentTimings.isEmpty) return;
    final currentPos = audioHandler.position.inMilliseconds / 1000.0;

    int currentIndex = _currentTimings.indexWhere(
      (t) => currentPos >= t.start && currentPos < t.end,
    );

    if (currentIndex != -1 && currentIndex + 1 < _currentTimings.length) {
      _seekToTiming(_currentTimings[currentIndex + 1]);
    } else {
      // Logic for gaps
      for (final t in _currentTimings) {
        if (t.start > currentPos) {
          _seekToTiming(t);
          break;
        }
      }
    }
  }

  void skipToPreviousVerse() {
    if (_currentTimings.isEmpty) return;
    final currentPos = audioHandler.position.inMilliseconds / 1000.0;

    int currentIndex = _currentTimings.indexWhere(
      (t) => currentPos >= t.start && currentPos < t.end,
    );

    if (currentIndex != -1) {
      if (currentIndex > 0) {
        _seekToTiming(_currentTimings[currentIndex - 1]);
      } else {
        audioHandler.seek(Duration.zero);
      }
    } else {
      // Logic for gaps (find last ended)
      for (int i = _currentTimings.length - 1; i >= 0; i--) {
        if (_currentTimings[i].end <= currentPos) {
          _seekToTiming(_currentTimings[i]);
          break;
        }
      }
    }
  }

  void _seekToTiming(AudioTiming t) {
    audioHandler.seek(Duration(milliseconds: (t.start * 1000).toInt()));
  }

  void seek(Duration position) {
    audioHandler.seek(position);
  }

  void play() {
    audioHandler.play();
  }

  void pause() {
    audioHandler.pause();
  }

  // --- Settings ---

  void setPlaybackSpeed(double speed) {
    playbackSpeedNotifier.value = speed;
    audioHandler.setSpeed(speed);
  }

  void setRepeatMode(AudioRepeatMode mode) {
    repeatModeNotifier.value = mode;
  }

  Future<void> setAudioSource(AudioSourceType source) async {
    if (audioSourceNotifier.value == source) return;
    audioSourceNotifier.value = source;

    // Reload if currently playing
    if (isVisibleNotifier.value && _loadedBookId != null) {
      await loadAndPlay(_loadedBookId!, _loadedChapter!, _loadedBookName!);
    }
  }

  void dispose() {
    _positionSubscription?.cancel();
    audioHandler.dispose();
    isVisibleNotifier.dispose();
    playbackSpeedNotifier.dispose();
    repeatModeNotifier.dispose();
    audioSourceNotifier.dispose();
  }
}
