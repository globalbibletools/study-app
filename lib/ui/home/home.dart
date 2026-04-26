import 'package:flutter/material.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/ui/home/appbar/reference_chooser/reference_chooser.dart';
import 'package:studyapp/ui/home/appbar/drawer.dart';
import 'package:studyapp/ui/home/panel_area/panel_area.dart';
import 'package:studyapp/ui/home/audio/audio_layer.dart';
import 'package:studyapp/ui/home/keypad/keypad_layer.dart';
import 'package:studyapp/ui/home/reading_session/reading_session_panel.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      manager.checkOnboarding(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager.init();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: AppDrawer(onSettingsClosed: manager.notifySettingsChanged),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ValueListenableBuilder<bool>(
        valueListenable: manager.readingSessionManager.readingModeNotifier,
        builder: (context, readingSessionStarted, child) {
          return ValueListenableBuilder<Reference>(
            valueListenable: manager.currentReference,
            builder: (context, ref, _) {
              return HomeAppBar(
                referenceChooserKey: manager.chooserKey,
                displayBookId: ref.bookId,
                displayChapter: ref.chapter,
                displayVerse: ref.verse,
                readingSessionStarted: readingSessionStarted,
                onBookSelected: (bookId) =>
                    manager.onBookSelected(context, bookId),
                onChapterSelected: manager.onChapterSelected,
                onVerseSelected: (verse) {
                  manager.syncController.jumpToVerse(
                    manager.currentBookId,
                    manager.currentChapter,
                    verse,
                  );
                },
                onInputModeChanged: manager.setInputMode,
                onTogglePanel: manager.togglePanelState,
                onPlayAudio: () => manager.toggleAudio(context),
                onAvailableDigitsChanged: manager.setEnabledDigits,
                onToggleReadingSession: () => toggleReadingSession(context),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Listener(
          onPointerDown: _handlePointerDown,
          behavior: HitTestBehavior.translucent,
          child: BiblePanelArea(manager: manager),
        ),
        AudioLayer(manager: manager),
        KeypadLayer(manager: manager),
      ],
    );
  }

  void _handlePointerDown(PointerDownEvent _) {
    FocusManager.instance.primaryFocus?.unfocus();

    if (manager.inputModeNotifier.value != ReferenceInputMode.none) {
      manager.resetKeypad();
    }
  }

  void toggleReadingSession(BuildContext context) {
    if (manager.readingSessionManager.readingModeNotifier.value) {
      manager.readingSessionManager.endReadingSession();
    } else {
      _openSheet(context);
    }
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ReadingSessionPanel(homeManager: manager);
      },
    );
  }
}
