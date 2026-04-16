import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/services/resources/remote_asset_service.dart';
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

enum AudioSourceType { heb, rdb, tk, jh }

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

  // Track what is currently playing
  int? _loadedBookId;
  int? _loadedChapter;
  String? _loadedBookName;
  bool _isStreamingSession = false;

  void setSyncController(ScrollSyncController controller) {
    _syncController = controller;
  }

  Future<void> loadAndPlay(
    int bookId,
    int chapter,
    String bookName, {
    int? startVerse,
    bool isAutoAdvance = false,
  }) async {
    final recordingId = AudioLogic.getRecordingId(
      bookId,
      chapter,
      audioSourceNotifier.value,
    );

    // 1. Get Asset config
    final asset = _assetService.getAudioChapterAsset(
      bookId: bookId,
      chapter: chapter,
      recordingId: recordingId,
    );

    if (asset == null) throw AudioMissingException(bookId, chapter);

    // 2. Determine path and update session type
    final exists = await _fileService.checkFileExists(
      asset.fileType,
      asset.localRelativePath,
    );

    // If the user explicitly loaded this (not an auto-advance), define the session
    if (!isAutoAdvance) {
      _isStreamingSession = !exists;
    }

    String uriPath;

    if (exists) {
      uriPath = await _fileService.getLocalPath(
        asset.fileType,
        asset.localRelativePath,
      );
      uriPath = Uri.file(uriPath).toString();
    } else {
      if (!AudioLogic.isAudioAvailable(bookId, chapter)) {
        stopAndClose();
        throw AudioMissingException(bookId, chapter);
      }
      uriPath = asset.remoteUrl;
    }

    _loadedBookId = bookId;
    _loadedChapter = chapter;
    _loadedBookName = bookName;
    isVisibleNotifier.value = true;

    // 3. Load Timings
    _currentTimings = await _audioDb.getTimingsForChapter(
      bookId,
      chapter,
      recordingId,
    );

    // 4. Sanitize
    if (_currentTimings.isNotEmpty) {
      final last = _currentTimings.last;
      if (last.end <= last.start) {
        _currentTimings.removeLast();
        _currentTimings.add(
          AudioTiming(
            verseId: last.verseId,
            start: last.start,
            end: double.infinity,
          ),
        );
      }
    }

    _lastSyncedVerse = -1;

    // 5. Load and Setup Listener
    try {
      await audioHandler.setUrl(
        uriPath,
        title: "$bookName $chapter",
        subtitle: bookName,
      );
    } catch (e) {
      stopAndClose();
      rethrow;
    }

    await audioHandler.setSpeed(playbackSpeedNotifier.value);
    _startSyncListener();

    // 6. Initial Highlight & Seek
    if (startVerse != null && _currentTimings.isNotEmpty) {
      final timing = _currentTimings.firstWhere(
        (t) => t.verseNumber == startVerse,
        orElse: () => _currentTimings.first,
      );
      _updateCurrentVerse(timing.verseNumber);

      // If starting from verse > 1, seek to that exact timing.
      // If startVerse is 1, let it play from the very beginning (0:00)
      // to include any audio intro/announcement.
      if (startVerse > 1) {
        await audioHandler.seek(
          Duration(milliseconds: (timing.start * 1000).toInt()),
        );
      }
    } else if (_currentTimings.isNotEmpty) {
      // Default to highlighting the first available verse immediately
      _updateCurrentVerse(_currentTimings.first.verseNumber);
    }

    audioHandler.play();
  }

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

    _playerStateSubscription = audioHandler.playerStateStream.listen((
      state,
    ) async {
      if (state.processingState == ProcessingState.completed) {
        if (repeatModeNotifier.value == AudioRepeatMode.chapter) {
          _lastSyncedVerse = -1;
          audioHandler.seek(Duration.zero);
        } else if (repeatModeNotifier.value == AudioRepeatMode.verse) {
          if (_currentTimings.isNotEmpty) {
            _seekToTiming(_currentTimings.last);
          }
        } else {
          _handleAutoAdvance();
        }
      }
    });

    if (_currentTimings.isEmpty) return;

    _positionSubscription = audioHandler.positionDataStream.listen((
      positionData,
    ) {
      if (_currentTimings.isEmpty) return;
      final currentSeconds = positionData.position.inMilliseconds / 1000.0;

      if (repeatModeNotifier.value == AudioRepeatMode.verse) {
        final currentMatch = _currentTimings.cast<AudioTiming?>().firstWhere(
          (t) => t?.verseNumber == _lastSyncedVerse,
          orElse: () => null,
        );
        if (currentMatch != null && currentSeconds >= currentMatch.end - 0.2) {
          audioHandler.seek(
            Duration(milliseconds: (currentMatch.start * 1000).toInt()),
          );
          return;
        }
      }

      // Normal Highlight Logic
      try {
        final match = _currentTimings.firstWhere(
          (t) => currentSeconds >= t.start && currentSeconds < t.end,
        );
        final verseNum = match.verseNumber;

        if (verseNum != _lastSyncedVerse) {
          _updateCurrentVerse(verseNum);
        }
      } catch (e) {
        // Fallback: We didn't match a specific timing.
        // If we are before the very first timing (e.g., in intro music/silence),
        // keep the first verse highlighted instead of clearing it.
        if (_currentTimings.isNotEmpty &&
            currentSeconds < _currentTimings.first.start) {
          final firstVerse = _currentTimings.first.verseNumber;
          if (firstVerse != _lastSyncedVerse) {
            _updateCurrentVerse(firstVerse);
          }
        } else {
          _clearHighlight();
        }
      }
    });
  }

  Future<void> _handleAutoAdvance() async {
    if (_loadedBookId != null &&
        _loadedChapter != null &&
        _loadedBookName != null) {
      final maxChapters = BibleNavigation.getChapterCount(_loadedBookId!);
      if (_loadedChapter! < maxChapters) {
        final nextChapter = _loadedChapter! + 1;
        final recordingId = AudioLogic.getRecordingId(
          _loadedBookId!,
          nextChapter,
          audioSourceNotifier.value,
        );
        final asset = _assetService.getAudioChapterAsset(
          bookId: _loadedBookId!,
          chapter: nextChapter,
          recordingId: recordingId,
        );

        if (asset != null) {
          final isNextDownloaded = await _fileService.checkFileExists(
            asset.fileType,
            asset.localRelativePath,
          );

          if (!_isStreamingSession && !isNextDownloaded) {
            // Fall through to stop playback
          } else {
            try {
              await loadAndPlay(
                _loadedBookId!,
                nextChapter,
                _loadedBookName!,
                isAutoAdvance: true,
              );
              _updateCurrentVerse(1);
              return;
            } catch (_) {}
          }
        }
      }
    }
    _clearHighlight();
    _lastSyncedVerse = -1;
    audioHandler.pause();
    audioHandler.seek(Duration.zero);
  }

  void _clearHighlight() {
    if (_loadedBookId != null && _loadedChapter != null) {
      _syncController?.setHighlight(_loadedBookId!, _loadedChapter!, null);
    }
  }

  void stopAndClose() {
    if (isVisibleNotifier.value) {
      isVisibleNotifier.value = false;
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
    const steps = 10;
    final stepDuration = Duration(milliseconds: 80);
    double startVolume = audioHandler.player.volume;
    double vol = startVolume;
    for (int i = 0; i < steps; i++) {
      if (!isVisibleNotifier.value) {
        await Future.delayed(stepDuration);
        vol -= (startVolume / steps);
        if (vol < 0) vol = 0;
        await audioHandler.player.setVolume(vol);
      }
    }
    await audioHandler.stop();
    await audioHandler.player.setVolume(startVolume);
  }

  void skipToNextVerse() {
    if (_currentTimings.isEmpty) return;
    final currentPos = audioHandler.position.inMilliseconds / 1000.0;
    int idx = _currentTimings.indexWhere(
      (t) => currentPos >= t.start && currentPos < t.end,
    );

    if (idx != -1 && idx + 1 < _currentTimings.length) {
      _seekToTiming(_currentTimings[idx + 1]);
    } else {
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
    int idx = _currentTimings.indexWhere(
      (t) => currentPos >= t.start && currentPos < t.end,
    );

    if (idx != -1 && idx > 0) {
      _seekToTiming(_currentTimings[idx - 1]);
    } else {
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
        // Also apply the fallback here just in case the user seeks into the intro manually
        if (seconds < _currentTimings.first.start) {
          _updateCurrentVerse(_currentTimings.first.verseNumber);
        } else {
          _clearHighlight();
        }
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
    if (startVerse != null &&
        startVerse != _lastSyncedVerse &&
        _currentTimings.isNotEmpty) {
      final t = _currentTimings.firstWhere(
        (t) => t.verseNumber == startVerse,
        orElse: () => _currentTimings.first,
      );
      _seekToTiming(t);
    }
    audioHandler.play();
  }

  void pause() => audioHandler.pause();

  void setPlaybackSpeed(double speed) {
    playbackSpeedNotifier.value = speed;
    audioHandler.setSpeed(speed);
  }

  void setRepeatMode(AudioRepeatMode mode) => repeatModeNotifier.value = mode;

  Future<void> setAudioSource(AudioSourceType source) async {
    if (audioSourceNotifier.value == source) return;
    audioSourceNotifier.value = source;
    if (isVisibleNotifier.value && _loadedBookId != null) {
      final v = _lastSyncedVerse > 0 ? _lastSyncedVerse : 1;
      await audioHandler.stop();
      await loadAndPlay(
        _loadedBookId!,
        _loadedChapter!,
        _loadedBookName!,
        startVerse: v,
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
