import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioPlayerHandler {
  final _player = AudioPlayer();

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<double> get speedStream => _player.speedStream;
  Duration get position => _player.position;

  /// Returns a stream of PositionData.
  /// This manually combines position, buffered position, and duration
  /// without using rxdart.
  Stream<PositionData> get positionDataStream {
    StreamController<PositionData>? controller;
    StreamSubscription? positionSub;
    StreamSubscription? bufferSub;
    StreamSubscription? durationSub;

    void emit() {
      if (controller != null && !controller.isClosed) {
        controller.add(
          PositionData(
            _player.position,
            _player.bufferedPosition,
            _player.duration ?? Duration.zero,
          ),
        );
      }
    }

    controller = StreamController<PositionData>(
      onListen: () {
        // Emit initial state
        emit();

        // Listen to all three streams and emit on any change
        positionSub = _player.positionStream.listen((_) => emit());
        bufferSub = _player.bufferedPositionStream.listen((_) => emit());
        durationSub = _player.durationStream.listen((_) => emit());
      },
      onCancel: () {
        positionSub?.cancel();
        bufferSub?.cancel();
        durationSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> init() async {
    await _player.setSpeed(1.0);
  }

  /// Loads the URL but does NOT auto-start playback.
  Future<void> setUrl(
    String url, {
    required String title,
    required String subtitle,
  }) async {
    try {
      final source = AudioSource.uri(
        Uri.parse(url),
        tag: MediaItem(id: url, album: subtitle, title: title),
      );
      await _player.setAudioSource(source);
    } catch (e) {
      debugPrint("Error loading audio: $e");
      rethrow;
    }
  }

  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  // Future<void> playUrl(
  //   String url, {
  //   required String title,
  //   required String subtitle,
  // }) async {
  //   try {
  //     final source = AudioSource.uri(
  //       Uri.parse(url),
  //       tag: MediaItem(
  //         id: url,
  //         album: subtitle, // We use album for Book Name
  //         title: title, // We use title for "Chapter X"
  //       ),
  //     );
  //     await _player.setAudioSource(source);
  //     await _player.play();
  //   } catch (e) {
  //     debugPrint("Error loading audio: $e");
  //   }
  // }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }

  // Helper for debug printing if needed
  void debugPrint(String msg) {
    // print(msg);
  }
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}
