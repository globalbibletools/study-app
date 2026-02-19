import 'package:flutter/material.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/ui/home/appbar/reference_chooser/reference_chooser.dart';
import 'package:studyapp/ui/home/appbar/drawer.dart';
import 'package:studyapp/ui/home/bible_panel_area.dart';
import 'package:studyapp/ui/home/audio/audio_layer.dart';
import 'package:studyapp/ui/home/keypad_layer.dart';

import 'appbar/appbar.dart';
import 'home_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final manager = HomeManager();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager.init();
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<Reference>(
          valueListenable: manager.currentReference,
          builder: (context, ref, child) {
            return HomeAppBar(
              // 1. Pass the key from the manager
              referenceChooserKey: manager.chooserKey,
              displayBookId: ref.bookId,
              displayChapter: ref.chapter,
              displayVerse: ref.verse,
              onBookSelected: (bookId) =>
                  manager.onBookSelected(context, bookId),
              onChapterSelected: (newChapter) =>
                  manager.onChapterSelected(newChapter),
              onVerseSelected: (verse) {
                manager.syncController.jumpToVerse(
                  manager.currentBookId,
                  manager.currentChapter,
                  verse,
                );
              },
              // 2. Update manager state instead of setState
              onInputModeChanged: manager.setInputMode,
              onTogglePanel: () => manager.togglePanelState(),
              onPlayAudio: () => manager.toggleAudio(context),
              onAvailableDigitsChanged: manager.setEnabledDigits,
            );
          },
        ),
      ),
      drawer: AppDrawer(
        onSettingsClosed: () => manager.notifySettingsChanged(),
      ),
      body: Stack(
        children: [
          // 1. Content Area
          Listener(
            onPointerDown: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              // 3. Check manager state to close keypad
              if (manager.inputModeNotifier.value != ReferenceInputMode.none) {
                manager.resetKeypad();
              }
            },
            behavior: HitTestBehavior.translucent,
            child: BiblePanelArea(manager: manager),
          ),

          // 2. Audio Layer
          AudioLayer(manager: manager),

          // 3. Keypad Layer
          KeypadLayer(manager: manager),
        ],
      ),
    );
  }
}
