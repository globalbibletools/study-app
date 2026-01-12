import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:studyapp/services/audio/position_data.dart';

class AudioPlayerHandler {
  final player = AudioPlayer();

  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  Stream<double> get speedStream => player.speedStream;
  Duration get position => player.position;

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
            player.position,
            player.bufferedPosition,
            player.duration ?? Duration.zero,
          ),
        );
      }
    }

    controller = StreamController<PositionData>(
      onListen: () {
        // Emit initial state
        emit();

        // Listen to all three streams and emit on any change
        positionSub = player.positionStream.listen((_) => emit());
        bufferSub = player.bufferedPositionStream.listen((_) => emit());
        durationSub = player.durationStream.listen((_) => emit());
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
    await player.setSpeed(1.0);
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
      await player.setAudioSource(source);
    } catch (e) {
      debugPrint("Error loading audio: $e");
      rethrow;
    }
  }

  Stream<SequenceState?> get sequenceStateStream => player.sequenceStateStream;

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

  Future<void> play() => player.play();
  Future<void> pause() => player.pause();
  Future<void> seek(Duration position) => player.seek(position);
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  Future<void> stop() async {
    await player.stop();
  }

  void dispose() {
    player.dispose();
  }

  // Helper for debug printing if needed
  void debugPrint(String msg) {
    // print(msg);
  }
}
