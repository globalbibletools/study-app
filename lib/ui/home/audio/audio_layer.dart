import 'package:flutter/material.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/ui/home/audio/audio_player.dart';
import 'package:gbt/ui/home/home_manager.dart';

// TODO: pull into audio_player widget.
class AudioLayer extends StatelessWidget {
  const AudioLayer({super.key, required this.manager});

  final HomeManager manager;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ValueListenableBuilder<bool>(
        valueListenable: manager.audioPlayerViewModel.isVisible,
        builder: (context, isVisible, _) {
          return AnimatedSlide(
            offset: isVisible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: ValueListenableBuilder<Reference>(
              valueListenable: manager.currentReference,
              builder: (context, ref, _) {
                return BottomAudioPlayer(
                  viewModel: manager.audioPlayerViewModel,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
