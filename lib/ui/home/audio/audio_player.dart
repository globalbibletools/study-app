import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:studyapp/services/audio/audio_player_handler.dart';

class BottomAudioPlayer extends StatelessWidget {
  final AudioPlayerHandler audioHandler;
  final VoidCallback onClose;

  const BottomAudioPlayer({
    super.key,
    required this.audioHandler,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh, // Modern surface color
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Controls
          Row(
            children: [
              // Play/Pause Button
              StreamBuilder<PlayerState>(
                stream: audioHandler.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final processingState = playerState?.processingState;
                  final playing = playerState?.playing;

                  if (processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering) {
                    return Container(
                      margin: const EdgeInsets.all(8.0),
                      width: 32.0,
                      height: 32.0,
                      child: const CircularProgressIndicator(),
                    );
                  } else if (playing != true) {
                    return IconButton(
                      icon: const Icon(Icons.play_circle_fill),
                      iconSize: 42.0,
                      color: colorScheme.primary,
                      onPressed: audioHandler.play,
                    );
                  } else {
                    return IconButton(
                      icon: const Icon(Icons.pause_circle_filled),
                      iconSize: 42.0,
                      color: colorScheme.primary,
                      onPressed: audioHandler.pause,
                    );
                  }
                },
              ),
              const SizedBox(width: 12),

              // Info Text (Placeholder for now, or stream MediaItem if desired)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Audio Player", // You could pass current Title here
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text("Listening...", style: theme.textTheme.bodySmall),
                  ],
                ),
              ),

              // Speed Control
              StreamBuilder<double>(
                stream: audioHandler.speedStream,
                builder: (context, snapshot) {
                  return IconButton(
                    icon: Text(
                      "${snapshot.data?.toStringAsFixed(1) ?? "1.0"}x",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onPressed: () {
                      _showSpeedDialog(context);
                    },
                  );
                },
              ),

              // Close Button
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  audioHandler.stop();
                  onClose();
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Progress Bar
          StreamBuilder<PositionData>(
            stream: audioHandler.positionDataStream,
            builder: (context, snapshot) {
              final positionData = snapshot.data;
              return ProgressBar(
                progress: positionData?.position ?? Duration.zero,
                buffered: positionData?.bufferedPosition ?? Duration.zero,
                total: positionData?.duration ?? Duration.zero,
                onSeek: audioHandler.seek,
                baseBarColor: colorScheme.outlineVariant,
                progressBarColor: colorScheme.primary,
                bufferedBarColor: colorScheme.primary.withOpacity(0.3),
                thumbColor: colorScheme.primary,
                thumbRadius: 6,
                timeLabelLocation: TimeLabelLocation.sides,
                timeLabelTextStyle: theme.textTheme.labelSmall,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSpeedDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Playback Speed",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                  return TextButton(
                    onPressed: () {
                      audioHandler.setSpeed(speed);
                      Navigator.pop(context);
                    },
                    child: Text("${speed}x"),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
