import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/rxutils/combine_streams.dart';
import 'package:gbt/services/audio/audio_service.dart';
import 'package:gbt/services/audio/audio_timing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

sealed class AudioPlaybackError {
  const AudioPlaybackError(this.reference);

  final Reference reference;
}

class AudioFileMissingError extends AudioPlaybackError {
  const AudioFileMissingError(super.reference);
}

class AudioUnknownError extends AudioPlaybackError {
  const AudioUnknownError(super.reference);
}

enum AudioRepeatModeType { none, chapter, verse }

class AudioRepeatMode {
    final AudioRepeatModeType type;
    final int? target;

    const AudioRepeatMode._(this.type) : target = null;

    static const none = AudioRepeatMode._(AudioRepeatModeType.none);
    static const chapter = AudioRepeatMode._(AudioRepeatModeType.chapter);
    AudioRepeatMode.verse(int this.target) : type = AudioRepeatModeType.verse;
}

class AudioPlayerViewModel extends ChangeNotifier {
    final isVisible = ValueNotifier(false);

    var repeatMode = AudioRepeatMode.none;
    void setRepeatMode(AudioRepeatMode mode) {
        repeatMode = mode;
        notifyListeners();
    }

    var audioSource = "RDB";
    void setAudioSource(String source) {
        audioSource = source;
        notifyListeners();
    }

    AudioPlaybackError? error;
    void setError(AudioPlaybackError? error) {
        this.error = error;
        notifyListeners();
    }

    late final Stream<Reference?> reference;
    late final Stream<({Duration? duration, Duration buffered, Duration position})> playback;

    final player = AudioPlayer();

    final _audioService = AudioService();
    List<AudioTiming> _timings = [];
    int? currentBook;
    int? currentChapter;

    AppLocalizations? _localizations;
    void setLocalizations(AppLocalizations localizations) {
        _localizations = localizations;
    }

    late final StreamSubscription positionSubscription;
    late final StreamSubscription processingStateSubscription;

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

        positionSubscription = player.positionStream.listen(_handleVerseRepeat);
        processingStateSubscription = player.processingStateStream.listen(_handleChapterRepeatOrContinue);
    }


    Future<void> changeRepeatMode(AudioRepeatModeType mode) async {
        switch (mode) {
            case AudioRepeatModeType.none:
                setRepeatMode(AudioRepeatMode.none);
                break;
            case AudioRepeatModeType.chapter:
                setRepeatMode(AudioRepeatMode.chapter);
                break;
            case AudioRepeatModeType.verse:
                final reference = getCurrentReference();
                if (reference == null) return;
                setRepeatMode(AudioRepeatMode.verse(reference.verse));
                break;
        }
    }

    Future<void> changeSource(String source) async {
        await _reload(source, getCurrentReference());
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

    Future<void> jumpTo(Reference reference) async {
        await _reload(audioSource, reference);
    }

    Future<void> jumpToNext() async {
        final currentReference = getCurrentReference();
        if (currentReference == null) return;

        final nextReference = _resolveNextVerse(currentReference);

        // End of the Bible.
        if (nextReference == null) {
            return;
        }

        await jumpTo(nextReference);
    }

    Future<void> jumpToPrev() async {
        final currentReference = getCurrentReference();
        if (currentReference == null) return;

        final timing = _referenceToTiming(currentReference);
        if (timing == null) return;

        // If we're more than a second into the current verse, restart it.
        final shouldRestartVerse = (player.position.inMilliseconds / 1000) - timing.start > 1;
        if (shouldRestartVerse) {
            await _seekToReference(currentReference);
            return;
        }

        final prevReference = _resolvePrevVerse(currentReference);

        // Beginning of the Bible, nothing to back up to.
        if (prevReference == null) {
            return;
        }

        await jumpTo(prevReference);
    }

    Future<void> _handleChapterRepeatOrContinue(ProcessingState state) async {
        if (state != ProcessingState.completed) return;

        final current = getCurrentReference();
        if (current == null) return;

        switch (repeatMode.type) {
            case AudioRepeatModeType.none:
                final nextReference = _resolveNextVerse(current);

                // End of the Bible, nothing to continue to.
                if (nextReference == null) {
                    await player.stop();
                    break;
                }

                // The next verse is within the chapter, so there is a hole in the audio.
                if (nextReference.bookId == current.bookId &&
                    nextReference.chapter == current.chapter) {
                    await player.pause();
                    break;
                }

                await _reload(audioSource, nextReference);
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
        if (repeatMode.type != AudioRepeatModeType.verse) return;

        final targetVerse = repeatMode.target;
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
        setError(null);
        _timings = [];
    }

    Future<void> _reload(String source, Reference? reference) async {
        if (repeatMode.type == AudioRepeatModeType.verse) {
            if (reference == null) {
                setRepeatMode(AudioRepeatMode.none);
            } else {
                setRepeatMode(AudioRepeatMode.verse(reference.verse));
            }
        }

        if (reference == null) {
            setAudioSource(source);
            return _reset();
        }

        final needsReload = currentBook != reference.bookId ||
            currentChapter != reference.chapter ||
            source != audioSource;
        if (!needsReload) {
            _seekToReference(reference);

            return;
        }

        currentChapter = reference.chapter;
        currentBook = reference.bookId;
        setAudioSource(source);

        String audioUrl;
        List<AudioTiming> timings;
        try {
            (:audioUrl, :timings) = await _audioService.getChapterData(
                audioSource,
                reference.bookId,
                reference.chapter
            );
        } on AudioMissingException {
            await _reset();
            setError(AudioFileMissingError(reference));
            return;
        }

        setError(null);
        _timings = timings;

        final wasPlaying = player.playing;

        final l = _localizations;
        final title = l == null
            ? "Bible"
            : "${bookNameFromLocalizations(l, reference.bookId)} ${reference.chapter}";

        await player.setAudioSource(AudioSource.uri(
            Uri.parse(audioUrl),
            tag: MediaItem(id: audioUrl, title: title)
        ));

        _seekToReference(reference);

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
        final verseCount = BibleNavigation.getVerseCount(current.bookId, current.chapter);
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

        return Reference(bookId: nextChapter.bookId, chapter: nextChapter.chapter, verse: 1);
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

        final lastVerse = BibleNavigation.getVerseCount(prevChapter.bookId, prevChapter.chapter);
        return Reference(bookId: prevChapter.bookId, chapter: prevChapter.chapter, verse: lastVerse);
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

    @override
    void dispose() {
        super.dispose();
        player.dispose();

        isVisible.dispose();

        processingStateSubscription.cancel();
        positionSubscription.cancel();
    }
}
