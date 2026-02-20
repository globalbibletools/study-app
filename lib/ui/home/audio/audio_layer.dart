import 'package:flutter/material.dart';
import 'package:studyapp/common/reference.dart';
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
            child: ValueListenableBuilder<Reference>(
              valueListenable: manager.currentReference,
              builder: (context, ref, _) {
                return BottomAudioPlayer(
                  audioManager: manager.audioManager,
                  currentBookId: ref.bookId,
                  currentChapter: ref.chapter,
                  currentVerse: ref.verse,
                  currentBookName: bookNameFromId(context, ref.bookId),
                  onAudioMissing: () {
                    manager.toggleAudio(context);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
