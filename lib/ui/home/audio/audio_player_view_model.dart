import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/rxutils/combine_streams.dart';
import 'package:gbt/services/audio/audio_service.dart';
import 'package:gbt/services/audio/audio_timing.dart';
import 'package:gbt/services/resources/resource.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

sealed class AudioPlaybackError {
  const AudioPlaybackError(this.reference);

  final Reference? reference;
}

class AudioFileMissingError extends AudioPlaybackError {
  const AudioFileMissingError(super.reference);
}

class AudioUnknownError extends AudioPlaybackError {
  const AudioUnknownError(super.reference);
}

enum AudioRepeatModeType { none, chapter, verse }

enum AudioPlaybackState { loading, playing, paused }

class AudioRepeatMode {
  final AudioRepeatModeType type;
  final int? target;

  const AudioRepeatMode._(this.type) : target = null;

  static const none = AudioRepeatMode._(AudioRepeatModeType.none);
  static const chapter = AudioRepeatMode._(AudioRepeatModeType.chapter);
  AudioRepeatMode.verse(int this.target) : type = AudioRepeatModeType.verse;
}

class SourceSetting {
  final String ot;
  final String nt;

  const SourceSetting({required this.ot, required this.nt});

  String forTestament(Testament testament) =>
      testament == Testament.ot ? ot : nt;

  SourceSetting withTestament(Testament testament, String source) {
    if (testament == Testament.ot) return SourceSetting(ot: source, nt: nt);
    return SourceSetting(ot: ot, nt: source);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceSetting && ot == other.ot && nt == other.nt;

  @override
  int get hashCode => Object.hash(ot, nt);
}

class AudioPlayerViewModel extends ChangeNotifier {
  var isVisible = false;
  void setVisibility(bool isVisible) {
    this.isVisible = isVisible;
    notifyListeners();
  }

  var repeatMode = AudioRepeatMode.none;
  void setRepeatMode(AudioRepeatMode mode) {
    if (repeatMode == mode) return;

    repeatMode = mode;
    notifyListeners();
  }

  var audioSource = const SourceSetting(ot: 'RDB', nt: 'TK');
  void setAudioSource(SourceSetting source) {
    if (audioSource == source) return;

    audioSource = source;
    notifyListeners();
  }

  Testament? get testament {
    final ref = reference.value;
    if (ref == null) return null;
    return AudioService.testamentForBookId(ref.bookId);
  }

  List<Resource> speakers = const [];
  void setSpeakers(List<Resource> value) {
    speakers = value;
    notifyListeners();
  }

  AudioPlaybackError? error;
  void setError(AudioPlaybackError? error) {
    if (this.error == error) return;

    this.error = error;
    notifyListeners();
  }

  double get speed => player.speed;
  void setSpeed(double speed) {
    if (speed == player.speed) return;

    player.setSpeed(speed);
    notifyListeners();
  }

  var playbackState = AudioPlaybackState.paused;
  void setPlaybackState(AudioPlaybackState state) {
    if (state == playbackState) return;

    playbackState = state;
    notifyListeners();
  }

  final reference = ValueNotifier<Reference?>(null);
  void setReference(Reference? reference) {
    if (this.reference.value == reference) return;

    this.reference.value = reference;
    notifyListeners();
  }

  late final Stream<
    ({Duration? duration, Duration buffered, Duration position})
  >
  playback;

  final player = AudioPlayer();

  final _audioService = AudioService();
  List<AudioTiming> _timings = [];

  AppLocalizations? _localizations;
  void setLocalizations(AppLocalizations localizations) {
    _localizations = localizations;
  }

  late final StreamSubscription positionSubscription;
  late final StreamSubscription playerStateSubscription;
  late final StreamSubscription errorSubscription;

  AudioPlayerViewModel() {
    playback = combineStreams3(
      player.durationStream,
      player.bufferedPositionStream,
      player.positionStream,
      (duration, buffered, position) =>
          (duration: duration, buffered: buffered, position: position),
    );

    positionSubscription = player.positionStream.listen(_positionStreamHandler);
    playerStateSubscription = player.playerStateStream.listen(
      _playerStateStreamHandler,
    );
    errorSubscription = player.errorStream.listen(_errorStreamHandler);
  }

  Future<void> changeRepeatMode(AudioRepeatModeType mode) async {
    if (!isVisible) return;

    switch (mode) {
      case AudioRepeatModeType.none:
        setRepeatMode(AudioRepeatMode.none);
        break;
      case AudioRepeatModeType.chapter:
        setRepeatMode(AudioRepeatMode.chapter);
        break;
      case AudioRepeatModeType.verse:
        if (reference.value case final reference?) {
          setRepeatMode(AudioRepeatMode.verse(reference.verse));
        }
        break;
    }
  }

  Future<void> changeSource(String source) async {
    if (!isVisible) return;

    final testament = this.testament;
    if (testament == null) return;

    await _reload(
      audioSource.withTestament(testament, source),
      reference.value,
    );
  }

  Future<void> openAt(Reference reference) async {
    setVisibility(true);
    await jumpTo(reference);
  }

  Future<void> close() async {
    setVisibility(false);
    await _reset();
  }

  Future<void> play() async {
    if (!isVisible) return;

    await player.play();
  }

  Future<void> pause() async {
    if (!isVisible) return;

    await player.pause();
  }

  Future<void> seek(Duration position) async {
    if (!isVisible) return;

    await player.seek(position);
  }

  Future<void> jumpTo(Reference reference) async {
    if (!isVisible) return;

    await _reload(audioSource, reference);
  }

  Future<void> jumpToNext() async {
    if (!isVisible) return;

    final reference = this.reference.value;
    if (reference == null) return;

    final nextReference = _resolveNextVerse(reference);

    // End of the Bible.
    if (nextReference == null) {
      return;
    }

    await jumpTo(nextReference);
  }

  Future<void> jumpToPrev() async {
    if (!isVisible) return;

    final reference = this.reference.value;
    if (reference == null) return;

    final timing = _referenceToTiming(reference);
    if (timing == null) return;

    // If we're more than a second into the current verse, restart it.
    final shouldRestartVerse =
        (player.position.inMilliseconds / 1000) - timing.start > 1;
    if (shouldRestartVerse) {
      await _seekToReference(reference);
      return;
    }

    final prevReference = _resolvePrevVerse(reference);

    // Beginning of the Bible, nothing to back up to.
    if (prevReference == null) {
      return;
    }

    await jumpTo(prevReference);
  }

  Future<void> _playerStateStreamHandler(PlayerState state) async {
    if (state.processingState != ProcessingState.completed) {
      if (state.processingState != ProcessingState.ready) {
        setPlaybackState(AudioPlaybackState.loading);
      } else if (state.playing) {
        setPlaybackState(AudioPlaybackState.playing);
      } else {
        setPlaybackState(AudioPlaybackState.paused);
      }
      return;
    }

    final reference = this.reference.value;
    if (reference == null) return;

    switch (repeatMode.type) {
      case AudioRepeatModeType.none:
        final nextReference = _resolveNextVerse(reference);

        // End of the Bible, nothing to continue to.
        if (nextReference == null) {
          await player.stop();
          break;
        }

        // The next verse is within the chapter, so there is a hole in the audio.
        if (nextReference.bookId == reference.bookId &&
            nextReference.chapter == reference.chapter) {
          await player.pause();
          break;
        }

        await _reload(audioSource, nextReference);
        break;
      case AudioRepeatModeType.chapter:
        await _seekToReference(
          Reference(
            bookId: reference.bookId,
            chapter: reference.chapter,
            verse: 1,
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _errorStreamHandler(Object error) async {
    debugPrint("Audio player error: $error");
    await _reset(error: AudioUnknownError(reference.value));
  }

  Future<void> _positionStreamHandler(Duration? position) async {
    if (position == null) {
      setReference(null);
      return;
    }

    final reference = _positionToReference(position);
    setReference(reference);

    if (repeatMode.type != AudioRepeatModeType.verse) return;

    final targetVerse = repeatMode.target;
    if (reference == null || targetVerse == null) return;

    final targetReference = Reference(
      bookId: reference.bookId,
      chapter: reference.chapter,
      verse: targetVerse,
    );

    final timing = _referenceToTiming(targetReference);
    if (timing == null) return;

    final beforeStart = position.inMilliseconds < timing.start * 1000;
    final pastEnd = position.inMilliseconds - (timing.end * 1000) >= -1;
    if (!beforeStart && !pastEnd) return;

    await _seekToReference(targetReference);
  }

  Future<void> _reset({ AudioPlaybackError? error }) async {
    await player.clearAudioSources();
    setReference(null);
    setError(error);
    setPlaybackState(AudioPlaybackState.paused);
    _timings = [];
  }

  Future<void> _reload(SourceSetting source, Reference? newReference) async {
    if (repeatMode.type == AudioRepeatModeType.verse) {
      if (newReference == null) {
        setRepeatMode(AudioRepeatMode.none);
      } else {
        setRepeatMode(AudioRepeatMode.verse(newReference.verse));
      }
    }

    if (newReference == null) {
      setAudioSource(source);
      return _reset();
    }

    final nextTestament = AudioService.testamentForBookId(newReference.bookId);
    final prevReference = reference.value;
    final prevTestament = prevReference == null
        ? null
        : AudioService.testamentForBookId(prevReference.bookId);

    if (nextTestament != prevTestament) {
      speakers = await _audioService.getSpeakers(nextTestament);
      if (speakers.isEmpty) {
        await _reset(error: AudioFileMissingError(newReference));
        return;
      }


      String speakerKey(String speakerId) => speakerId.substring(speakerId.indexOf('/') + 1);
      final sourceAvailable =
          speakers.any((s) => speakerKey(s.id) == source.forTestament(nextTestament));
      if (!sourceAvailable) {
        source = source.withTestament(nextTestament, speakerKey(speakers.first.id));
      }
    }

    final oldSource = audioSource;
    setAudioSource(source);

    final activeSource = source.forTestament(nextTestament);
    final needsReload =
        prevReference?.bookId != newReference.bookId ||
        prevReference?.chapter != newReference.chapter ||
        activeSource != oldSource.forTestament(nextTestament);
    if (!needsReload) {
      _seekToReference(newReference);

      return;
    }

    String audioUrl;
    List<AudioTiming> timings;
    try {
      (:audioUrl, :timings) = await _audioService.getChapterData(
        activeSource,
        newReference.bookId,
        newReference.chapter,
      );
    } on AudioMissingException {
      await _reset(error: AudioFileMissingError(newReference));
      return;
    }

    setError(null);
    _timings = timings;

    final l = _localizations;
    final title = l == null
        ? "Bible"
        : "${bookNameFromLocalizations(l, newReference.bookId)} ${newReference.chapter}";

    final wasPlaying = player.playing;
    try {
        await player.setAudioSource(
          AudioSource.uri(
            Uri.parse(audioUrl),
            tag: MediaItem(id: audioUrl, title: title),
          ),
        );
    } catch (error) {
        debugPrint("Failed to load audio: $error");
        await _reset(error: AudioUnknownError(newReference));
    }

    _seekToReference(newReference);
    setReference(newReference);

    if (wasPlaying) {
      await player.play();
    }
  }

  AudioTiming? _referenceToTiming(Reference reference) {
    if (reference.verse < 1 || reference.verse > _timings.length) {
      return null;
    }
    try {
      return _timings.firstWhere((t) => t.verseNumber == reference.verse);
    } catch (error) {
      return null;
    }
  }

  Future<void> _seekToReference(Reference reference) async {
    final timing = _referenceToTiming(reference);
    if (timing != null) {
      await player.seek(Duration(milliseconds: (timing.start * 1000).toInt()));
    }
  }

  Reference? _resolveNextVerse(Reference current) {
    final verseCount = BibleNavigation.getVerseCount(
      current.bookId,
      current.chapter,
    );
    if (current.verse < verseCount) {
      return Reference(
        bookId: current.bookId,
        chapter: current.chapter,
        verse: current.verse + 1,
      );
    }

    final nextChapter = BibleNavigation.getNextChapter(
      ChapterIdentifier(current.bookId, current.chapter),
    );
    if (nextChapter == null) return null;

    return Reference(
      bookId: nextChapter.bookId,
      chapter: nextChapter.chapter,
      verse: 1,
    );
  }

  Reference? _resolvePrevVerse(Reference current) {
    if (current.verse > 1) {
      return Reference(
        bookId: current.bookId,
        chapter: current.chapter,
        verse: current.verse - 1,
      );
    }

    final prevChapter = BibleNavigation.getPreviousChapter(
      ChapterIdentifier(current.bookId, current.chapter),
    );
    if (prevChapter == null) return null;

    final lastVerse = BibleNavigation.getVerseCount(
      prevChapter.bookId,
      prevChapter.chapter,
    );
    return Reference(
      bookId: prevChapter.bookId,
      chapter: prevChapter.chapter,
      verse: lastVerse,
    );
  }

  Reference? _positionToReference(Duration position) {
    final reference = this.reference.value;
    if (reference == null) return null;

    try {
      final timing = _timings.reversed.firstWhere(
        (t) => t.start * 1000 <= position.inMilliseconds,
      );

      return Reference(
        bookId: reference.bookId,
        chapter: reference.chapter,
        verse: timing.verseNumber,
      );
    } catch (err) {
      return null;
    }
  }

  @override
  void dispose() {
    super.dispose();
    player.dispose();

    playerStateSubscription.cancel();
    positionSubscription.cancel();
    errorSubscription.cancel();
  }
}
