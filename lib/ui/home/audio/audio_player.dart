import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:studyapp/services/audio/position_data.dart';

import 'audio_manager.dart';

class BottomAudioPlayer extends StatelessWidget {
  final AudioManager audioManager;

  const BottomAudioPlayer({super.key, required this.audioManager});

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- ROW 1: Settings | Progress | Close ---
          Row(
            children: [
              // Settings Button
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                visualDensity: VisualDensity.compact,
                tooltip: "Audio Settings",
                onPressed: () => _showSettingsBottomSheet(context),
              ),

              const SizedBox(width: 8),

              // Progress Bar
              Expanded(
                child: StreamBuilder<PositionData>(
                  stream: audioManager.audioHandler.positionDataStream,
                  builder: (context, snapshot) {
                    final positionData = snapshot.data;
                    return ProgressBar(
                      progress: positionData?.position ?? Duration.zero,
                      buffered: positionData?.bufferedPosition ?? Duration.zero,
                      total: positionData?.duration ?? Duration.zero,
                      onSeek: audioManager.seek,
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
                      timeLabelTextStyle: theme.textTheme.labelSmall,
                      timeLabelPadding: 8.0,
                    );
                  },
                ),
              ),

              const SizedBox(width: 8),

              // Close Button
              IconButton(
                icon: const Icon(Icons.close),
                visualDensity: VisualDensity.compact,
                onPressed: audioManager.stopAndClose,
              ),
            ],
          ),

          const SizedBox(height: 4),

          // --- ROW 2: Previous | Play/Pause | Next ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous Verse
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                iconSize: 24,
                color: colorScheme.primary,
                onPressed: audioManager.skipToPreviousVerse,
              ),

              const SizedBox(width: 24),

              // Play/Pause
              _PlayButton(audioManager: audioManager),

              const SizedBox(width: 24),

              // Next Verse
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                iconSize: 24,
                color: colorScheme.primary,
                onPressed: audioManager.skipToNextVerse,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow sheet to size itself
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return _AudioSettingsSheet(manager: audioManager);
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  final AudioManager audioManager;
  const _PlayButton({required this.audioManager});

  @override
  Widget build(BuildContext context) {
    // We use the primary color for the icon itself
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StreamBuilder<PlayerState>(
      stream: audioManager.audioHandler.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final playing = playerState?.playing;

        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          // Loading Spinner
          return SizedBox(
            width: 48,
            height: 48,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
          );
        } else if (playing != true) {
          // Play Button
          return IconButton(
            icon: const Icon(Icons.play_arrow_rounded),
            iconSize: 48.0,
            color: primaryColor,
            padding: EdgeInsets.zero,
            onPressed: audioManager.play,
          );
        } else {
          // Pause Button
          return IconButton(
            icon: const Icon(Icons.pause_rounded),
            iconSize: 48.0,
            color: primaryColor,
            padding: EdgeInsets.zero,
            onPressed: audioManager.pause,
          );
        }
      },
    );
  }
}

// --- SETTINGS BOTTOM SHEET ---

class _AudioSettingsSheet extends StatelessWidget {
  final AudioManager manager;

  const _AudioSettingsSheet({required this.manager});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text("Audio Settings", style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 24),

          // 1. Playback Speed (Segmented Button with Scroll)
          Text("Playback Speed", style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ValueListenableBuilder<double>(
            valueListenable: manager.playbackSpeedNotifier,
            builder: (context, currentSpeed, _) {
              return SizedBox(
                width: double.infinity,
                child: SegmentedButton<double>(
                  showSelectedIcon: false, // Save space
                  segments: const [
                    ButtonSegment(value: 0.5, label: Text("0.5")),
                    ButtonSegment(value: 0.75, label: Text("0.75")),
                    ButtonSegment(value: 1.0, label: Text("1.0")),
                    ButtonSegment(value: 1.5, label: Text("1.5")),
                    ButtonSegment(value: 2.0, label: Text("2.0")),
                  ],
                  selected: {currentSpeed},
                  onSelectionChanged: (Set<double> newSelection) {
                    manager.setPlaybackSpeed(newSelection.first);
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // 2. Repeat Mode (Segmented Button)
          Text("Repeat Mode", style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ValueListenableBuilder<AudioRepeatMode>(
            valueListenable: manager.repeatModeNotifier,
            builder: (context, currentMode, _) {
              return SizedBox(
                width: double.infinity,
                child: SegmentedButton<AudioRepeatMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AudioRepeatMode.none,
                      label: Text("None"),
                    ),
                    ButtonSegment(
                      value: AudioRepeatMode.verse,
                      label: Text("Verse"),
                    ),
                    ButtonSegment(
                      value: AudioRepeatMode.chapter,
                      label: Text("Chapter"),
                    ),
                  ],
                  selected: {currentMode},
                  onSelectionChanged: (Set<AudioRepeatMode> newSelection) {
                    manager.setRepeatMode(newSelection.first);
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // 3. Recording Source (Segmented Button)
          Text("Recording Source", style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ValueListenableBuilder<AudioSourceType>(
            valueListenable: manager.audioSourceNotifier,
            builder: (context, currentSource, _) {
              return SizedBox(
                width: double.infinity,
                child: SegmentedButton<AudioSourceType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AudioSourceType.heb,
                      label: Text("Hebrew (HEB)"),
                    ),
                    ButtonSegment(
                      value: AudioSourceType.rdb,
                      label: Text("Reading (RDB)"),
                    ),
                  ],
                  selected: {currentSource},
                  onSelectionChanged: (Set<AudioSourceType> newSelection) {
                    manager.setAudioSource(newSelection.first);
                  },
                ),
              );
            },
          ),

          // Extra padding at bottom for safety on devices without safe area
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
