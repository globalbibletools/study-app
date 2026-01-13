import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:studyapp/services/audio/audio_database.dart';
import 'package:studyapp/services/audio/audio_player_handler.dart';
import 'package:studyapp/services/audio/audio_timing.dart';
import 'package:studyapp/services/audio/audio_url_helper.dart';
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/ui/home/common/scroll_sync_controller.dart';

class AudioMissingException implements Exception {
  final int bookId;
  final int chapter;
  AudioMissingException(this.bookId, this.chapter);
}

enum AudioRepeatMode { none, chapter, verse }

enum AudioSourceType { heb, rdb }

class AudioManager {
  final AudioPlayerHandler audioHandler = AudioPlayerHandler();
  final _audioDb = getIt<AudioDatabase>();
  final _fileService = getIt<FileService>();

  // --- State Notifiers ---
  final isVisibleNotifier = ValueNotifier<bool>(false);
  final playbackSpeedNotifier = ValueNotifier<double>(1.0);
  final repeatModeNotifier = ValueNotifier<AudioRepeatMode>(
    AudioRepeatMode.none,
  );
  final audioSourceNotifier = ValueNotifier<AudioSourceType>(
    AudioSourceType.rdb,
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

  Future<void> loadAndPlay(
    int bookId,
    int chapter,
    String bookName, {
    int? startVerse,
  }) async {
    final recordingId = audioSourceNotifier.value == AudioSourceType.heb
        ? 'HEB'
        : 'RDB';

    final relativePath = AudioUrlHelper.getLocalRelativePath(
      bookId: bookId,
      chapter: chapter,
      recordingId: recordingId,
    );

    final exists = await _fileService.checkFileExists(
      FileType.audio,
      relativePath,
    );

    if (!exists) {
      stopAndClose();
      throw AudioMissingException(bookId, chapter);
    }

    final localFullPath = await _fileService.getLocalPath(
      FileType.audio,
      relativePath,
    );

    _loadedBookId = bookId;
    _loadedChapter = chapter;
    _loadedBookName = bookName;
    isVisibleNotifier.value = true;

    _currentTimings = await _audioDb.getTimingsForChapter(
      bookId,
      chapter,
      recordingId,
    );

    // Sanitize bad data for the last verse
    if (_currentTimings.isNotEmpty) {
      final last = _currentTimings.last;
      if (last.end <= last.start) {
        _currentTimings.removeLast();
        _currentTimings.add(
          AudioTiming(verseId: last.verseId, start: last.start, end: 36000.0),
        );
      }
    }

    _lastSyncedVerse = -1;

    await audioHandler.setUrl(
      Uri.file(localFullPath).toString(),
      title: "$bookName $chapter",
      subtitle: bookName,
    );

    await audioHandler.setSpeed(playbackSpeedNotifier.value);
    _startSyncListener();

    // --- SEEK TO START VERSE LOGIC ---
    if (startVerse != null && startVerse > 1 && _currentTimings.isNotEmpty) {
      // Find the timing that corresponds to the startVerse
      // Using 'orElse' to be safe, though startVerse usually exists if validated by UI
      final timing = _currentTimings.firstWhere(
        (t) => t.verseNumber == startVerse,
        orElse: () => _currentTimings.first,
      );

      // Update state immediately so repeat logic knows where we are
      _updateCurrentVerse(timing.verseNumber);

      // Seek to the start of the verse
      await audioHandler.seek(
        Duration(milliseconds: (timing.start * 1000).toInt()),
      );
    }

    audioHandler.play();
  }

  /// Updates internal state and UI immediately during manual navigation
  void _updateCurrentVerse(int verseNum) {
    _lastSyncedVerse = verseNum;
    if (_loadedBookId != null && _loadedChapter != null) {
      _syncController?.setHighlight(_loadedBookId!, _loadedChapter!, verseNum);
      _syncController?.jumpToVerse(
        _loadedBookId!,
        _loadedChapter!,
        verseNum,
        isAuto: true,
      );
    }
  }

  void _startSyncListener() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();

    // Handle End of Chapter
    _playerStateSubscription = audioHandler.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // --- CHECK REPEAT MODE ---
        if (repeatModeNotifier.value == AudioRepeatMode.chapter) {
          // REPEAT CHAPTER:
          _lastSyncedVerse = -1;
          // Seek to beginning (Audio stays 'playing' automatically)
          audioHandler.seek(Duration.zero);
        } else if (repeatModeNotifier.value == AudioRepeatMode.verse) {
          // EDGE CASE: If repeating the LAST verse, the file finishes before
          // the timestamp check triggers (due to the 36000s fix).
          // So if we hit 'completed' in verse mode, repeat the last verse.
          if (_currentTimings.isNotEmpty) {
            _seekToTiming(_currentTimings.last);
          }
        } else {
          // NO REPEAT (Standard Stop Logic):

          // Clear UI Highlight
          if (_loadedBookId != null && _loadedChapter != null) {
            _syncController?.setHighlight(
              _loadedBookId!,
              _loadedChapter!,
              null,
            );
          }
          _lastSyncedVerse = -1;

          // Reset Player (Pause & Rewind)
          audioHandler.pause();
          audioHandler.seek(Duration.zero);
        }
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
        _clearHighlight();
        return;
      }

      final verseNum = match.verseNumber;

      // Update Highlight
      if (_loadedBookId != null && _loadedChapter != null) {
        _syncController?.setHighlight(
          _loadedBookId!,
          _loadedChapter!,
          verseNum,
        );
      }

      // Update Jump
      if (verseNum != _lastSyncedVerse) {
        _lastSyncedVerse = verseNum;
        if (_loadedBookId != null && _loadedChapter != null) {
          _syncController?.jumpToVerse(
            _loadedBookId!,
            _loadedChapter!,
            verseNum,
            isAuto: true,
          );
        }
      }
    });
  }

  void _clearHighlight() {
    if (_loadedBookId != null && _loadedChapter != null) {
      _syncController?.setHighlight(_loadedBookId!, _loadedChapter!, null);
    }
  }

  // --- Controls ---

  void stopAndClose() {
    if (isVisibleNotifier.value) {
      // Trigger UI animation immediately
      isVisibleNotifier.value = false;

      // Start fade out operation
      _fadeOut().then((_) {
        _positionSubscription?.cancel();
        _playerStateSubscription?.cancel();
        _currentTimings = [];
        _clearHighlight();
        _loadedBookId = null;
      });
    }
  }

  Future<void> _fadeOut() async {
    const duration = Duration(milliseconds: 800);
    const steps = 10;
    final stepDuration = duration ~/ steps;

    // Get current volume or default to 1.0
    double startVolume = audioHandler.player.volume;
    double vol = startVolume;

    for (int i = 0; i < steps; i++) {
      if (!isVisibleNotifier.value) {
        // If UI is already closed/closing, we proceed with fade
        await Future.delayed(stepDuration);
        vol -= (startVolume / steps);
        if (vol < 0) vol = 0;
        await audioHandler.player.setVolume(vol);
      }
    }

    await audioHandler.stop();
    // Restore volume for next time
    await audioHandler.player.setVolume(startVolume);
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
        if (_currentTimings.isNotEmpty) {
          _seekToTiming(_currentTimings.first);
        } else {
          audioHandler.seek(Duration.zero);
        }
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
    _updateCurrentVerse(t.verseNumber);
    audioHandler.seek(Duration(milliseconds: (t.start * 1000).toInt()));
  }

  void seek(Duration position) {
    if (_currentTimings.isNotEmpty) {
      final seconds = position.inMilliseconds / 1000.0;
      try {
        final match = _currentTimings.firstWhere(
          (t) => seconds >= t.start && seconds < t.end,
        );
        _updateCurrentVerse(match.verseNumber);
      } catch (_) {
        // Seeking to a gap or end; let the listener handle it normally
      }
    }
    audioHandler.seek(position);
  }

  Future<void> play({
    int? checkBookId,
    int? checkChapter,
    String? checkBookName,
    int? startVerse,
  }) async {
    // Check if the user has scrolled to a new chapter while paused/stopped
    if (checkBookId != null && checkChapter != null && checkBookName != null) {
      if (checkBookId != _loadedBookId || checkChapter != _loadedChapter) {
        // User is looking at a different chapter. Load it, starting at the specific verse.
        await loadAndPlay(
          checkBookId,
          checkChapter,
          checkBookName,
          startVerse: startVerse,
        );
        return;
      }
    }

    // Resuming existing audio.
    // If a specific verse is requested (e.g. from Play button while scrolled elsewhere), seek to it.
    if (startVerse != null && _currentTimings.isNotEmpty) {
      final timing = _currentTimings.firstWhere(
        (t) => t.verseNumber == startVerse,
        orElse: () => _currentTimings.first,
      );
      _updateCurrentVerse(timing.verseNumber);
      await audioHandler.seek(
        Duration(milliseconds: (timing.start * 1000).toInt()),
      );
    }

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
    _playerStateSubscription?.cancel();
    audioHandler.dispose();
    isVisibleNotifier.dispose();
    playbackSpeedNotifier.dispose();
    repeatModeNotifier.dispose();
    audioSourceNotifier.dispose();
  }
}
