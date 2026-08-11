import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:gbt/services/audio/position_data.dart';

class AudioPlayerHandler {
  final player = AudioPlayer();

  // PositionData stream backing state.
  late final StreamController<PositionData> _positionDataController;
  PositionData _latestPositionData =
      PositionData(Duration.zero, Duration.zero, Duration.zero);
  StreamSubscription? _positionSub;
  StreamSubscription? _bufferSub;
  StreamSubscription? _durationSub;

  AudioPlayerHandler() {
    _positionDataController = StreamController<PositionData>.broadcast(
      onListen: () {
        // Replay the latest value to new listeners.
        _positionDataController.add(_latestPositionData);
      },
    );

    void emit() {
      _latestPositionData = PositionData(
        player.position,
        player.bufferedPosition,
        player.duration ?? Duration.zero,
      );
      if (!_positionDataController.isClosed) {
        _positionDataController.add(_latestPositionData);
      }
    }

    _positionSub = player.positionStream.listen((_) => emit());
    _bufferSub = player.bufferedPositionStream.listen((_) => emit());
    _durationSub = player.durationStream.listen((_) => emit());
  }

  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  Stream<double> get speedStream => player.speedStream;
  Duration get position => player.position;

  /// Returns a broadcast stream of PositionData.
  /// This manually combines position, buffered position, and duration
  /// without using rxdart. The latest value is replayed to late listeners,
  /// and the stream is explicitly reset when audio sources are cleared
  /// (see [clearUrl]).
  Stream<PositionData> get positionDataStream => _positionDataController.stream;

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

  Future<void> clearUrl() async {
    await player.clearAudioSources();
    _resetPositionData();
  }

  /// Emits a zeroed-out PositionData so listeners (e.g. progress UI)
  /// reset when there is no audio source loaded.
  void _resetPositionData() {
    _latestPositionData =
        PositionData(Duration.zero, Duration.zero, Duration.zero);
    if (!_positionDataController.isClosed) {
      _positionDataController.add(_latestPositionData);
    }
  }

  Stream<SequenceState?> get sequenceStateStream => player.sequenceStateStream;

  Future<void> play() => player.play();
  Future<void> pause() => player.pause();
  Future<void> seek(Duration position) => player.seek(position);
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  Future<void> stop() async {
    await player.stop();
  }

  void dispose() {
    _positionSub?.cancel();
    _bufferSub?.cancel();
    _durationSub?.cancel();
    _positionDataController.close();
    player.dispose();
  }

  // Helper for debug printing if needed
  void debugPrint(String msg) {
    // print(msg);
  }
}
