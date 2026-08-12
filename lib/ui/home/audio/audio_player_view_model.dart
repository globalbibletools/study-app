import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/audio/audio_service.dart';
import 'package:gbt/services/audio/audio_timing.dart';
import 'package:just_audio/just_audio.dart';

enum AudioPlaybackError { fileMissing, unknown }

class TrackingStreamController<T> {
    final _controller = StreamController<T>.broadcast();

    bool get isClosed => _controller.isClosed;
    Stream<T> get stream => _controller.stream;
    Future<dynamic> close() => _controller.close();

    T _current;
    T get current => _current;

    TrackingStreamController(this._current);

    void add(T newValue) {
        _current = newValue;
        _controller.add(newValue);
    }
}

class AudioPlayerViewModel {
    // TODO: init these from user preferences
    final audioSource = ValueNotifier("RDB");
    final isVisible = ValueNotifier(false);
    final error = ValueNotifier<AudioPlaybackError?>(null);
    final referenceController = TrackingStreamController<Reference?>(null);

    // TODO: speed and loop mode can bind directly to streams on player.
    final player = AudioPlayer();

    final _audioService = AudioService();
    List<AudioTiming> _timings = [];

    Future<void> openAt(Reference reference) async {
        isVisible.value = true;

        await _reload(audioSource.value, reference);
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

    void seek(Duration position) {
        player.seek(position);
    }

    Future<void> jumpTo(Reference reference) async {
        await _reload(audioSource.value, reference);

        if (reference.verse < 1 || reference.verse > _timings.length) {
            // TODO: maybe add some logging or user visible error handling here.
            return;
        }

        final seekPosition = _timings[reference.verse - 1];

        player.seek(Duration(milliseconds: (seekPosition.start * 1000).toInt()));
    }

    Future<void> jumpToNext() async {
        final currentReference = referenceController.current;
        if (currentReference == null) return;

        await jumpTo(Reference(
          bookId: currentReference.bookId,
          chapter: currentReference.chapter,
          verse: currentReference.verse + 1,
        ));
    }

    Future<void> jumpToPrev() async {
        final currentReference = referenceController.current;
        if (currentReference == null) return;

        await jumpTo(Reference(
          bookId: currentReference.bookId,
          chapter: currentReference.chapter,
          verse: currentReference.verse - 1,
        ));
    }

    Future<void> setSource(String source) async {
        audioSource.value = source;
        await _reload(source, referenceController.current);
    }

    Future<void> _reload(String source, Reference? reference) async {
        if (reference == null) return _reset();

        final currentReference = referenceController.current;

        final needsReload = currentReference?.bookId != reference.bookId ||
            currentReference?.chapter != reference.chapter ||
            source != audioSource.value;
        if (!needsReload) {
            return;
        }

        // TODO: catch source errors and missing audio files and handle gracefully.
        final (:audioUrl, :timings) = await _audioService.getChapterData(
            audioSource.value,
            reference.bookId,
            reference.chapter
        );

        _timings = timings;

        await player.setAudioSource(AudioSource.uri(
            Uri.parse(audioUrl),
            // TODO: add tag: MediaItem with metadata
        ));
    }

    Future<void> _reset() async {
        await player.stop();
        referenceController.add(null);
    }

    void dispose() {
        player.dispose();
        audioSource.dispose();
        isVisible.dispose();
        error.dispose();
    }
}
