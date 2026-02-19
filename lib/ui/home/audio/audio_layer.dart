import 'package:flutter/material.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/ui/home/audio/audio_player.dart';
import 'package:studyapp/ui/home/home_manager.dart';

class AudioLayer extends StatelessWidget {
  const AudioLayer({super.key, required this.manager});

  final HomeManager manager;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ValueListenableBuilder<bool>(
        valueListenable: manager.audioManager.isVisibleNotifier,
        builder: (context, isVisible, _) {
          return AnimatedSlide(
            offset: isVisible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: BottomAudioPlayer(
              audioManager: manager.audioManager,
              currentBookId: manager.currentBookId,
              currentChapter: manager.currentChapter,
              currentVerse: manager.currentVerse,
              currentBookName: bookNameFromId(context, manager.currentBookId),
              // We can still link the missing callback to the manager's logic
              // purely for the "Play" button inside the player itself.
              // Note: The toggleAudio handles the initial check, this handles
              // errors that might happen *during* playback or internal retry.
              onAudioMissing: () {
                // We don't have access to the private _promptDownloadAudio,
                // but we can just trigger toggleAudio which will detect it's missing.
                manager.toggleAudio(context);
              },
            ),
          );
        },
      ),
    );
  }
}
