import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/services/assets/remote_asset_service.dart';
import 'package:studyapp/services/audio/audio_database.dart';
import 'package:studyapp/services/audio/audio_player_handler.dart';
import 'package:studyapp/services/audio/audio_timing.dart';
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/ui/home/audio/audio_logic.dart';
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
  final _assetService = getIt<RemoteAssetService>();

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
    final recordingId = AudioLogic.getRecordingId(
      bookId,
      audioSourceNotifier.value,
    );

    // Get the Asset Configuration
    final asset = _assetService.getAudioChapterAsset(
      bookId: bookId,
      chapter: chapter,
      recordingId: recordingId,
    );

    if (asset == null) {
      throw AudioMissingException(bookId, chapter);
    }

    // Check for local file using Asset config
    final exists = await _fileService.checkFileExists(
      asset.fileType,
      asset.localRelativePath,
    );

    String uriPath;

    if (exists) {
      // Get absolute path for local playback
      uriPath = await _fileService.getLocalPath(
        asset.fileType,
        asset.localRelativePath,
      );
      uriPath = Uri.file(uriPath).toString();
    } else {
      // Check if audio is theoretically available (Business Logic)
      if (!AudioLogic.isAudioAvailable(bookId, chapter)) {
        stopAndClose();
        throw AudioMissingException(bookId, chapter);
      }

      // Stream from Remote URL
      uriPath = asset.remoteUrl;
    }

    _loadedBookId = bookId;
    _loadedChapter = chapter;
    _loadedBookName = bookName;
    isVisibleNotifier.value = true;

    // Load Timings (These are always local in the SQLite DB)
    _currentTimings = await _audioDb.getTimingsForChapter(
      bookId,
      chapter,
      recordingId,
    );

    // Sanitize bad data
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

    // Set Audio Source
    try {
      await audioHandler.setUrl(
        uriPath,
        title: "$bookName $chapter",
        subtitle: bookName,
      );
    } catch (e) {
      // Handle network errors for streaming
      stopAndClose();
      rethrow;
    }

    await audioHandler.setSpeed(playbackSpeedNotifier.value);
    _startSyncListener();

    // Seek logic
    if (startVerse != null && startVerse > 1 && _currentTimings.isNotEmpty) {
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

    // Handle End of Chapter for ALL books (even if NT has no timings)
    _playerStateSubscription = audioHandler.playerStateStream.listen((
      state,
    ) async {
      if (state.processingState == ProcessingState.completed) {
        // --- CHECK REPEAT MODE ---
        if (repeatModeNotifier.value == AudioRepeatMode.chapter) {
          // REPEAT CHAPTER:
          _lastSyncedVerse = -1;
          audioHandler.seek(Duration.zero);
        } else if (repeatModeNotifier.value == AudioRepeatMode.verse) {
          // EDGE CASE: If repeating the LAST verse...
          if (_currentTimings.isNotEmpty) {
            _seekToTiming(_currentTimings.last);
          }
        } else {
          // NO REPEAT (Auto-Play Next Chapter or Standard Stop Logic)
          bool playedNext = false;

          // 1. Check if we can play the next chapter
          if (_loadedBookId != null &&
              _loadedChapter != null &&
              _loadedBookName != null) {
            final maxChapters = BibleNavigation.getChapterCount(_loadedBookId!);

            // If we aren't at the end of the book
            if (_loadedChapter! < maxChapters) {
              final nextChapter = _loadedChapter! + 1;
              final recordingId = AudioLogic.getRecordingId(
                _loadedBookId!,
                audioSourceNotifier.value,
              );

              final asset = _assetService.getAudioChapterAsset(
                bookId: _loadedBookId!,
                chapter: nextChapter,
                recordingId: recordingId,
              );

              // 2. Check if the file is actually downloaded locally
              if (asset != null) {
                final exists = await _fileService.checkFileExists(
                  asset.fileType,
                  asset.localRelativePath,
                );

                if (exists) {
                  try {
                    // 3. Play next chapter automatically
                    await loadAndPlay(
                      _loadedBookId!,
                      nextChapter,
                      _loadedBookName!,
                    );
                    _updateCurrentVerse(1); // Jump UI to verse 1
                    playedNext = true;
                  } catch (e) {
                    debugPrint("Error auto-playing next chapter: $e");
                  }
                }
              }
            }
          }

          // 4. If we didn't play the next chapter (streaming, or end of book), stop normally
          if (!playedNext) {
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
      }
    });

    // If no timings (NT), we just want basic playback without sync logic.
    // We put this HERE so the end-of-chapter listener above still works for NT.
    if (_currentTimings.isEmpty) {
      return;
    }

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
    // Check if the user has navigated to a DIFFERENT chapter while paused
    if (checkBookId != null && checkChapter != null && checkBookName != null) {
      if (checkBookId != _loadedBookId || checkChapter != _loadedChapter) {
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
    // Only seek to startVerse if it's DIFFERENT from our current position.
    // If we just scrubbed, startVerse will equal _lastSyncedVerse, so we DON'T seek.
    if (startVerse != null &&
        startVerse != _lastSyncedVerse &&
        _currentTimings.isNotEmpty) {
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
      // Capture current verse before stopping
      final currentVerse = _lastSyncedVerse > 0 ? _lastSyncedVerse : 1;

      // Stop playback explicitly before loading the new source.
      await audioHandler.stop();

      // Attempt to load the new source with the captured verse.
      await loadAndPlay(
        _loadedBookId!,
        _loadedChapter!,
        _loadedBookName!,
        startVerse: currentVerse,
      );
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
