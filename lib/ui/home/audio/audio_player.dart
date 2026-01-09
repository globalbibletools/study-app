import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:studyapp/l10n/app_localizations.dart';
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
        color: colorScheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PlayButton(audioHandler: audioHandler),

          const SizedBox(width: 12),

          // RIGHT: Info + Progress Bar
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title --- Speed | Close
                Row(
                  children: [
                    // Title (Book Chapter)
                    Expanded(
                      child: StreamBuilder<SequenceState?>(
                        stream: audioHandler.sequenceStateStream,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
                          final title = state?.currentSource?.tag is MediaItem
                              ? (state!.currentSource!.tag as MediaItem).title
                              : '';

                          return Text(
                            title,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),

                    // Speed
                    StreamBuilder<double>(
                      stream: audioHandler.speedStream,
                      builder: (context, snapshot) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => _showSpeedDialog(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              "${snapshot.data?.toStringAsFixed(1) ?? "1.0"}x",
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 8),

                    // Close
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      padding: EdgeInsets.zero, // Remove internal padding
                      constraints:
                          const BoxConstraints(), // Remove minimum size constraints
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        audioHandler.stop();
                        onClose();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Bottom: Progress Bar
                StreamBuilder<PositionData>(
                  stream: audioHandler.positionDataStream,
                  builder: (context, snapshot) {
                    final positionData = snapshot.data;
                    return ProgressBar(
                      progress: positionData?.position ?? Duration.zero,
                      buffered: positionData?.bufferedPosition ?? Duration.zero,
                      total: positionData?.duration ?? Duration.zero,
                      onSeek: audioHandler.seek,
                      barHeight: 4.0,
                      thumbRadius: 6.0,
                      thumbGlowRadius: 12.0,
                      baseBarColor: colorScheme.outlineVariant,
                      progressBarColor: colorScheme.primary,
                      bufferedBarColor: colorScheme.primary.withValues(
                        alpha: 0.3,
                      ),
                      thumbColor: colorScheme.primary,
                      timeLabelLocation: TimeLabelLocation.sides,
                      timeLabelTextStyle: theme.textTheme.labelLarge,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSpeedDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.audioPlaybackSpeed,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [0.5, 0.8, 1.0, 1.5, 2.0].map((speed) {
                  return TextButton(
                    onPressed: () {
                      audioHandler.setSpeed(speed);
                      Navigator.pop(context);
                    },
                    child: Text("${speed}x"),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  final AudioPlayerHandler audioHandler;
  const _PlayButton({required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<PlayerState>(
      stream: audioHandler.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final playing = playerState?.playing;

        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          return Container(
            margin: const EdgeInsets.all(4.0),
            width: 34.0, // Matching rough size of icon
            height: 34.0,
            child: const CircularProgressIndicator(strokeWidth: 3),
          );
        } else if (playing != true) {
          return IconButton(
            // Use the "Old" filled circle style
            icon: const Icon(Icons.play_circle_fill),
            iconSize: 42.0,
            color: colorScheme.primary,
            padding: EdgeInsets.zero, // Remove padding to keep compact
            constraints: const BoxConstraints(), // Tight constraints
            onPressed: audioHandler.play,
          );
        } else {
          return IconButton(
            // Use the "Old" filled circle style
            icon: const Icon(Icons.pause_circle_filled),
            iconSize: 42.0,
            color: colorScheme.primary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: audioHandler.pause,
          );
        }
      },
    );
  }
}
