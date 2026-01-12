import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/audio/position_data.dart';

import 'audio_manager.dart';

class BottomAudioPlayer extends StatelessWidget {
  final AudioManager audioManager;
  final int currentBookId;
  final int currentChapter;
  final String currentBookName;

  const BottomAudioPlayer({
    super.key,
    required this.audioManager,
    required this.currentBookId,
    required this.currentChapter,
    required this.currentBookName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

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
          // --- ROW 1: Voice Settings | Progress | Close ---
          Row(
            children: [
              // Voice Source Button (Person Head)
              _VoiceMenuButton(audioManager: audioManager),

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

          // --- ROW 2: Repeat | Controls | Speed ---
          // Using Expanded on left and right allows the center controls
          // to stay perfectly centered regardless of button width changes.
          Row(
            children: [
              // Far Left: Repeat Mode
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _RepeatMenuButton(audioManager: audioManager),
                ),
              ),

              // Center: Playback Controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Previous Verse
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    iconSize: 28,
                    color: colorScheme.primary,
                    onPressed: audioManager.skipToPreviousVerse,
                  ),

                  const SizedBox(width: 12),

                  // Play/Pause
                  _PlayButton(
                    audioManager: audioManager,
                    bookId: currentBookId,
                    chapter: currentChapter,
                    bookName: currentBookName,
                  ),

                  const SizedBox(width: 12),

                  // Next Verse
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    iconSize: 28,
                    color: colorScheme.primary,
                    onPressed: audioManager.skipToNextVerse,
                  ),
                ],
              ),

              // Far Right: Playback Speed
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _SpeedMenuButton(audioManager: audioManager),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- SUB-WIDGETS ---

class _VoiceMenuButton extends StatelessWidget {
  final AudioManager audioManager;

  const _VoiceMenuButton({required this.audioManager});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AudioSourceType>(
      valueListenable: audioManager.audioSourceNotifier,
      builder: (context, currentSource, _) {
        return PopupMenuButton<AudioSourceType>(
          icon: const Icon(Icons.person_outline),
          tooltip: 'Voice',
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: audioManager.setAudioSource,
          itemBuilder: (BuildContext context) {
            return [
              // Shmueloff
              CheckedPopupMenuItem<AudioSourceType>(
                value: AudioSourceType.heb,
                checked: currentSource == AudioSourceType.heb,
                child: const Text("Shmueloff"),
              ),
              // Dan Beeri
              CheckedPopupMenuItem<AudioSourceType>(
                value: AudioSourceType.rdb,
                checked: currentSource == AudioSourceType.rdb,
                child: const Text("Dan Beeri"),
              ),
            ];
          },
        );
      },
    );
  }
}

class _RepeatMenuButton extends StatelessWidget {
  final AudioManager audioManager;

  const _RepeatMenuButton({required this.audioManager});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AudioRepeatMode>(
      valueListenable: audioManager.repeatModeNotifier,
      builder: (context, currentMode, _) {
        IconData iconData;
        Color iconColor;
        final theme = Theme.of(context);

        // Determine Icon and Color
        switch (currentMode) {
          case AudioRepeatMode.none:
            iconData = Icons.repeat;
            // Primary color with alpha to indicate "Off" / Disabled state
            iconColor = theme.colorScheme.primary.withValues(alpha: 0.3);
            break;
          case AudioRepeatMode.verse:
            iconData = Icons.repeat_one_rounded;
            iconColor = theme.colorScheme.primary;
            break;
          case AudioRepeatMode.chapter:
            iconData = Icons.repeat_rounded;
            iconColor = theme.colorScheme.primary;
            break;
        }

        return PopupMenuButton<AudioRepeatMode>(
          icon: Icon(iconData, color: iconColor),
          tooltip: 'Repeat Mode',
          offset: const Offset(0, -120),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: audioManager.setRepeatMode,
          itemBuilder: (BuildContext context) {
            final l10n = AppLocalizations.of(context)!;
            return [
              CheckedPopupMenuItem<AudioRepeatMode>(
                value: AudioRepeatMode.none,
                checked: currentMode == AudioRepeatMode.none,
                child: Text(l10n.repeatNone), // "Off"
              ),
              CheckedPopupMenuItem<AudioRepeatMode>(
                value: AudioRepeatMode.verse,
                checked: currentMode == AudioRepeatMode.verse,
                child: Text(l10n.repeatVerse), // "Repeat Verse"
              ),
              CheckedPopupMenuItem<AudioRepeatMode>(
                value: AudioRepeatMode.chapter,
                checked: currentMode == AudioRepeatMode.chapter,
                child: Text(l10n.repeatChapter), // "Repeat Chapter"
              ),
            ];
          },
        );
      },
    );
  }
}

class _SpeedMenuButton extends StatelessWidget {
  final AudioManager audioManager;

  const _SpeedMenuButton({required this.audioManager});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: audioManager.playbackSpeedNotifier,
      builder: (context, currentSpeed, _) {
        final colorScheme = Theme.of(context).colorScheme;

        // Displays "1.0x", "0.75x", "1.5x" etc.
        String label = "${currentSpeed}x";

        return PopupMenuButton<double>(
          tooltip: 'Playback Speed',
          offset: const Offset(0, -220),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: audioManager.setPlaybackSpeed,
          itemBuilder: (BuildContext context) {
            const speeds = [0.5, 0.75, 0.85, 1.0, 1.2, 1.5];
            return speeds.map((speed) {
              return CheckedPopupMenuItem<double>(
                value: speed,
                checked: currentSpeed == speed,
                child: Text("${speed}x"),
              );
            }).toList();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary, // Primary color for text
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.audioManager,
    required this.bookId,
    required this.chapter,
    required this.bookName,
  });

  final AudioManager audioManager;
  final int bookId;
  final int chapter;
  final String bookName;

  static const _size = 48.0;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StreamBuilder<PlayerState>(
      stream: audioManager.audioHandler.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final playing = playerState?.playing;

        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          return SizedBox(
            width: _size,
            height: _size,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          );
        } else if (playing != true) {
          return IconButton(
            icon: const Icon(Icons.play_circle_fill_rounded),
            iconSize: _size,
            color: primaryColor,
            padding: EdgeInsets.zero,
            onPressed: () {
              audioManager.play(
                checkBookId: bookId,
                checkChapter: chapter,
                checkBookName: bookName,
              );
            },
          );
        } else {
          return IconButton(
            icon: const Icon(Icons.pause_circle_filled_rounded),
            iconSize: _size,
            color: primaryColor,
            padding: EdgeInsets.zero,
            onPressed: audioManager.pause,
          );
        }
      },
    );
  }
}
