import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/ui/home/audio/audio_player_view_model.dart';
import 'package:gbt/l10n/app_localizations.dart';

class BottomAudioPlayer extends StatelessWidget {
  final AudioPlayerViewModel viewModel;

  const BottomAudioPlayer({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    viewModel.setLocalizations(AppLocalizations.of(context)!);

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
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (buildContext, _) =>
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- ROW 0: Reference / Error ---
                  _ReferenceOrErrorRow(
                    error: viewModel.error,
                    reference: viewModel.reference.value,
                  ),

                  const SizedBox(height: 2),

                  // --- ROW 1: Voice Settings | Progress | Close ---
                  Row(
                    children: [
                      // Voice Source Button (Person Head)
                      _VoiceMenuButton(
                        isNewTestament: (viewModel.reference.value?.bookId ?? 0) >= BibleNavigation.getNewTestamentBookId(),
                        source: viewModel.audioSource,
                        onChange: viewModel.changeSource,
                      ),
                      const SizedBox(width: 8),

                      // Progress Bar
                      Expanded(
                        child: StreamBuilder<({Duration? duration, Duration buffered, Duration position })>(
                          stream: viewModel.playback,
                          builder: (context, snapshot) {
                            final playback = snapshot.data;
                            return ProgressBar(
                              progress: playback?.position ?? Duration.zero,
                              buffered: playback?.buffered ?? Duration.zero,
                              total: playback?.duration ?? Duration.zero,
                              onSeek: viewModel.error == null ? viewModel.seek : null,
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
                        onPressed: viewModel.close,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // --- ROW 2: Repeat | Controls | Speed ---
                  Row(
                    children: [
                      // Far Left: Repeat Mode
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _RepeatMenuButton(
                            repeatMode: viewModel.repeatMode,
                            onChange: viewModel.changeRepeatMode,
                          )
                        ),
                      ),

                      // Center: Playback Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            iconSize: 28,
                            color: colorScheme.primary,
                            onPressed: viewModel.error == null
                                ? viewModel.jumpToPrev
                                : null,
                          ),

                          const SizedBox(width: 12),

                          // Play/Pause
                          _PlayButton(
                            playbackState: viewModel.playbackState,
                            onPlay: viewModel.error == null ? viewModel.play : null,
                            onPause: viewModel.error == null ? viewModel.pause : null,
                          ),

                          const SizedBox(width: 12),

                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            iconSize: 28,
                            color: colorScheme.primary,
                            onPressed: viewModel.error == null
                                ? viewModel.jumpToNext
                                : null,
                          ),
                        ],
                      ),

                      // Far Right: Playback Speed
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _SpeedMenuButton(
                            speed: viewModel.speed,
                            onChange: viewModel.setSpeed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
      )
    );
  }
}

// --- SUB-WIDGETS ---

class _ReferenceOrErrorRow extends StatelessWidget {
  final AudioPlaybackError? error;
  final Reference? reference;

  const _ReferenceOrErrorRow({
    required this.error,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (error == null) {
      final refText = reference == null
          ? ''
          : '${bookNameFromId(context, reference!.bookId)} ${reference!.chapter}:${reference!.verse}';
      return Text(
        refText,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final bookName = bookNameFromId(context, error!.reference.bookId);
    final chapter = error!.reference.chapter;
    final String text; switch (error!) {
      case AudioFileMissingError():
        text = l10n.audioNotAvailableForChapter(bookName, chapter);
      case AudioUnknownError():
        text = l10n.unknownAudioError;
    }
    final color = theme.colorScheme.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _VoiceMenuButton extends StatelessWidget {
  final bool isNewTestament;
  final String source;
  final Function(String) onChange;

  const _VoiceMenuButton({
    required this.isNewTestament,
    required this.source,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.person_outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: onChange,
      itemBuilder: (BuildContext context) {
        final l10n = AppLocalizations.of(context)!;

        if (isNewTestament) {
          return [
            CheckedPopupMenuItem<String>(
              value: 'TK',
              checked: source == 'TK',
              child: Text(l10n.sourceTK),
            ),
            CheckedPopupMenuItem<String>(
              value: 'JH',
              checked: source == 'JH',
              child: Text(l10n.sourceJH),
            ),
          ];
        } else {
          return [
            CheckedPopupMenuItem<String>(
              value: 'HEB',
              checked: source == 'HEB',
              child: Text(l10n.sourceHEB),
            ),
            CheckedPopupMenuItem<String>(
              value: 'RDB',
              checked: source == 'RDB',
              child: Text(l10n.sourceRDB),
            ),
          ];
        }
      },
    );
  }
}

class _RepeatMenuButton extends StatelessWidget {
  final AudioRepeatMode repeatMode;
  final Function(AudioRepeatModeType) onChange;

  const _RepeatMenuButton({required this.repeatMode, required this.onChange});

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;
    final theme = Theme.of(context);

    // Determine Icon and Color
    switch (repeatMode.type) {
      case AudioRepeatModeType.none:
        iconData = Icons.repeat;
        // Primary color with alpha to indicate "Off" / Disabled state
        iconColor = theme.colorScheme.primary.withValues(alpha: 0.3);
      case AudioRepeatModeType.verse:
        iconData = Icons.repeat_one_rounded;
        iconColor = theme.colorScheme.primary;
      case AudioRepeatModeType.chapter:
        iconData = Icons.repeat_rounded;
        iconColor = theme.colorScheme.primary;
    }

    return PopupMenuButton<AudioRepeatModeType>(
      icon: Icon(iconData, color: iconColor),
      offset: const Offset(0, -120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: onChange,
      itemBuilder: (BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        return [
          CheckedPopupMenuItem<AudioRepeatModeType>(
            value: AudioRepeatModeType.none,
            checked: repeatMode.type == AudioRepeatModeType.none,
            child: Text(l10n.repeatNone), // "Off"
          ),
          CheckedPopupMenuItem<AudioRepeatModeType>(
            value: AudioRepeatModeType.verse,
            checked: repeatMode.type == AudioRepeatModeType.verse,
            child: Text(l10n.repeatVerse), // "Repeat Verse"
          ),
          CheckedPopupMenuItem<AudioRepeatModeType>(
            value: AudioRepeatModeType.chapter,
            checked: repeatMode.type == AudioRepeatModeType.chapter,
            child: Text(l10n.repeatChapter), // "Repeat Chapter"
          ),
        ];
      },
    );
  }
}

class _SpeedMenuButton extends StatelessWidget {
  final double speed;
  final Function(double) onChange;

  const _SpeedMenuButton({
    required this.speed,
    required this.onChange
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Displays "1.0x", "0.75x", "1.5x" etc.
    String label = "${speed}x";

    return PopupMenuButton<double>(
      offset: const Offset(0, -220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: onChange,
      itemBuilder: (BuildContext context) {
        const speeds = [0.5, 0.75, 0.85, 1.0, 1.2, 1.5];
        return speeds.map((speedOption) {
          return CheckedPopupMenuItem<double>(
            value: speedOption,
            checked: speed == speedOption,
            child: Text("${speedOption}x"),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playbackState,
    required this.onPlay,
    required this.onPause,
  });

  final AudioPlaybackState playbackState;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;

  static const _size = 48.0;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    switch (playbackState) {
        case AudioPlaybackState.loading:
          return SizedBox(
            width: _size,
            height: _size,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          );
        case AudioPlaybackState.paused:
          return IconButton(
            icon: const Icon(Icons.play_circle_fill_rounded),
            iconSize: _size,
            color: primaryColor,
            padding: EdgeInsets.zero,
            onPressed: onPlay,
          );
        case AudioPlaybackState.playing:
          return IconButton(
            icon: const Icon(Icons.pause_circle_filled_rounded),
            iconSize: _size,
            color: primaryColor,
            padding: EdgeInsets.zero,
            onPressed: onPause,
          );
    }
  }
}
