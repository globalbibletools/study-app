import 'package:flutter/material.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/rxutils/combine_streams.dart';
import 'package:gbt/services/audio/audio_service.dart';
import 'package:gbt/services/audio/audio_timing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

enum AudioPlaybackError { fileMissing, unknown }

enum AudioRepeatModeType { none, chapter, verse }

class AudioRepeatMode {
    final AudioRepeatModeType type;
    final int? target;

    const AudioRepeatMode._(this.type) : target = null;

    static const none = AudioRepeatMode._(AudioRepeatModeType.none);
    static const chapter = AudioRepeatMode._(AudioRepeatModeType.chapter);
    AudioRepeatMode.verse(int this.target) : type = AudioRepeatModeType.verse;
}

class AudioPlayerViewModel {
    // TODO: init these from user preferences
    final repeatMode = ValueNotifier(AudioRepeatMode.none);
    final audioSource = ValueNotifier("RDB");
    final isVisible = ValueNotifier(false);
    final error = ValueNotifier<AudioPlaybackError?>(null);
    late final Stream<Reference?> reference;
    late final Stream<({Duration? duration, Duration buffered, Duration position})> playback;

    final player = AudioPlayer();

    final _audioService = AudioService();
    List<AudioTiming> _timings = [];
    int? currentBook;
    int? currentChapter;

    Reference? getCurrentReference() => _positionToReference(player.position);

    AudioPlayerViewModel() {
        playback = combineStreams3(
            player.durationStream,
            player.bufferedPositionStream,
            player.positionStream,
            (duration, buffered, position) => (
                duration: duration,
                buffered: buffered,
                position: position,
              )
        );
        reference = player.positionStream.map(_positionToReference);

        // TODO: cleanup these subscriptions in dispose
        player.positionStream.listen(_handleVerseRepeat);
        player.processingStateStream.listen(_handleChapterRepeatOrContinue);
    }

    Future<void> openAt(Reference reference) async {
        isVisible.value = true;
        await jumpTo(reference);
    }

    Future<void> close() async {
        await _reset();
        isVisible.value = false;
    }

    Future<void> play() async {
        await player.play();
    }

    Future<void> pause() async {
        await player.pause();
    }

    Future<void> seek(Duration position) async {
        await player.seek(position);
    }

    Future<void> jumpTo(Reference reference, { bool play = false }) async {
        if (repeatMode.value.type == AudioRepeatModeType.verse) {
            repeatMode.value = AudioRepeatMode.verse(reference.verse);
        }

        await _reload(audioSource.value, reference);

        if (play && !player.playing) {
            await this.play();
        }
    }

    Future<void> jumpToNext() async {
        final currentReference = getCurrentReference();
        if (currentReference == null) return;

        if (repeatMode.value.type == AudioRepeatModeType.verse) {
            repeatMode.value = AudioRepeatMode.verse(currentReference.verse + 1);
        }

        await _seekToReference(Reference(
          bookId: currentReference.bookId,
          chapter: currentReference.chapter,
          verse: currentReference.verse + 1,
        ));
    }

    Future<void> jumpToPrev() async {
        final currentReference = getCurrentReference();
        debugPrint("current reference = $currentReference");
        if (currentReference == null) return;

        final timing = _referenceToTiming(currentReference);
        if (timing == null) return;

        final shouldRestartVerse = (player.position.inMilliseconds / 1000) - timing.start > 1;
        if (shouldRestartVerse) {
            await _seekToReference(Reference(
              bookId: currentReference.bookId,
              chapter: currentReference.chapter,
              verse: currentReference.verse,
            ));
        } else {
            if (repeatMode.value.type == AudioRepeatModeType.verse) {
                repeatMode.value = AudioRepeatMode.verse(currentReference.verse - 1);
            }

            await _seekToReference(Reference(
              bookId: currentReference.bookId,
              chapter: currentReference.chapter,
              verse: currentReference.verse - 1,
            ));
        }
    }

    Future<void> setRepeatMode(AudioRepeatModeType mode) async {
        switch (mode) {
            case AudioRepeatModeType.none:
                repeatMode.value = AudioRepeatMode.none;
                break;
            case AudioRepeatModeType.chapter:
                repeatMode.value = AudioRepeatMode.chapter;
                break;
            case AudioRepeatModeType.verse:
                final reference = getCurrentReference();
                if (reference == null) return;
                repeatMode.value = AudioRepeatMode.verse(reference.verse);
                break;
        }
    }

    Future<void> setSource(String source) async {
        await _reload(source, getCurrentReference());
    }

    Future<void> _handleChapterRepeatOrContinue(ProcessingState state) async {
        if (state != ProcessingState.completed) return;

        final current = getCurrentReference();
        if (current == null) return;

        switch (repeatMode.value.type) {
            case AudioRepeatModeType.none:
                // TODO: handle book transitions
                _reload(audioSource.value, Reference(
                    bookId: current.bookId,
                    chapter: current.chapter + 1,
                    verse: 1
                ));
                break;
            case AudioRepeatModeType.chapter:
                await _seekToReference(Reference(
                    bookId: current.bookId,
                    chapter: current.chapter,
                    verse: 1
                ));
                break;
            default:
                break;
        }
    }

    Future<void> _handleVerseRepeat(Duration? position) async {
        if (repeatMode.value.type != AudioRepeatModeType.verse) return;

        final targetVerse = repeatMode.value.target;
        final reference = getCurrentReference();
        if (position == null || reference == null || targetVerse == null) return;

        final targetReference = Reference(
            bookId: reference.bookId,
            chapter: reference.chapter,
            verse: targetVerse
        );

        final timing = _referenceToTiming(targetReference);
        if (timing == null) return;

        final beforeStart = position.inMilliseconds < timing.start * 1000;
        final pastEnd = position.inMilliseconds - (timing.end * 1000) >= -1;
        if (!beforeStart && !pastEnd) return;

        await _seekToReference(targetReference);
    }

    Future<void> _reset() async {
        currentBook = null;
        currentChapter = null;
        await player.seek(Duration(seconds: 0));
        await player.stop();
        await player.clearAudioSources();
        error.value = null;
        _timings = [];
    }

    Future<void> _reload(String source, Reference? reference) async {
        if (reference == null) {
            audioSource.value = source;
            return _reset();
        }

        final currentReference = getCurrentReference();

        final needsReload = currentReference?.bookId != reference.bookId ||
            currentReference?.chapter != reference.chapter ||
            source != audioSource.value;
        if (!needsReload) {
            _seekToReference(reference);

            return;
        }

        currentChapter = reference.chapter;
        currentBook = reference.bookId;
        audioSource.value = source;

        // TODO: catch source errors and missing audio files and handle gracefully.
        final (:audioUrl, :timings) = await _audioService.getChapterData(
            audioSource.value,
            reference.bookId,
            reference.chapter
        );

        _timings = timings;

        final wasPlaying = player.playing;

        await player.setAudioSource(AudioSource.uri(
            Uri.parse(audioUrl),
            tag: MediaItem(id: audioUrl, title: "Bible")
        ));

        _seekToReference(reference);

        if (wasPlaying) {
            await player.play();
        }
    }

    AudioTiming? _referenceToTiming(Reference reference) {
        if (reference.verse < 1 || reference.verse > _timings.length) {
            // TODO: maybe add some logging or user visible error handling here.
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

    Reference? _positionToReference(Duration position) {
        if (currentBook == null || currentChapter == null) return null;

        try {
            final timing = _timings.reversed.firstWhere((t) => t.start * 1000 <= position.inMilliseconds);

            return Reference(
                bookId: currentBook!,
                chapter: currentChapter!,
                verse: timing.verseNumber,
            );
        } catch (err) {
            return null;
        }
    }

    void dispose() {
        // TODO: figure out how to dispose the combined stream, or if necessary since it is dervied from the player
        player.dispose();
        audioSource.dispose();
        isVisible.dispose();
        error.dispose();
    }
}
