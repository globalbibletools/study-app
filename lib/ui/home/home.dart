import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/ui/home/bible_panel/bible_panel.dart';
import 'package:studyapp/ui/home/appbar/drawer.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/panel.dart';

import 'appbar/reference_chooser.dart';
import 'common/scroll_sync_controller.dart';
import 'home_manager.dart';

enum DownloadDialogChoice { useEnglish, download }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final manager = HomeManager();
  final syncController = ScrollSyncController();

  // "Panel" State: Triggers infinite scroll reset only when explicitly changed by User
  late int panelBookId;
  late int panelChapter;

  // "Display" State: Updates freely while scrolling or selecting
  late int displayBookId;
  late int displayChapter;
  int displayVerse = 1;

  @override
  void initState() {
    super.initState();

    final (initialBook, initialChapter) = manager.getInitialBookAndChapter();
    // Initialize both sets of state
    panelBookId = initialBook;
    panelChapter = initialChapter;

    displayBookId = initialBook;
    displayChapter = initialChapter;

    // Listen to scroll updates
    syncController.addListener(_onScrollUpdate);
  }

  void _onScrollUpdate() {
    // Only update if we have valid data
    if (syncController.bookId != null && syncController.chapter != null) {
      final newBook = syncController.bookId!;
      final newChapter = syncController.chapter!;
      final newVerse = syncController.verse;

      // Only change the verse if the controller reported a valid one
      final effectiveVerse = newVerse ?? displayVerse;

      // Avoid setState if nothing changed
      if (newBook != displayBookId ||
          newChapter != displayChapter ||
          effectiveVerse != displayVerse) {
        setState(() {
          displayBookId = newBook;
          displayChapter = newChapter;
          displayVerse = effectiveVerse;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager.init(context);
  }

  @override
  void dispose() {
    syncController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: ReferenceChooser(
          currentBookName: bookNameFromId(context, displayBookId),
          currentBookId: displayBookId,
          currentChapter: displayChapter,
          currentVerse: displayVerse,
          onBookSelected: (bookId) async {
            _onUserNavigation(bookId, 1, 1);
          },
          onChapterSelected: (newChapter) {
            _onUserNavigation(displayBookId, newChapter, 1);
          },
          onVerseSelected: (verse) {
            _scrollToVerse(verse);
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              manager.togglePanelState();
              _syncManagerToDisplay();
              _requestText();
            },
            icon: const Icon(Icons.splitscreen),
          ),
        ],
      ),
      drawer: AppDrawer(
        onSettingsClosed: () {
          setState(() {
            // _fontScale = manager.getFontScale();
          });
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: HebrewGreekPanel(
              bookId: panelBookId,
              chapter: panelChapter,
              syncController: syncController,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: manager.isSinglePanelNotifier,
            builder: (context, isSinglePanel, child) {
              if (isSinglePanel) return const SizedBox();
              return Expanded(
                child: BiblePanel(
                  bookId: panelBookId,
                  chapter: panelChapter,
                  syncController: syncController,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<int> top = <int>[];
  List<int> bottom = <int>[0];

  /// Handles explicit user navigation (selecting from menus)
  void _onUserNavigation(int bId, int ch, int v) {
    setState(() {
      // 1. Update Display
      displayBookId = bId;
      displayChapter = ch;
      displayVerse = v;

      // 2. Update Panel (Forces reset/jump)
      panelBookId = bId;
      panelChapter = ch;
    });

    // 3. Update Manager (for single panel mode fetching)
    manager.onBookSelected(context, bId);
    manager.currentChapterNotifier.value = ch;

    // 4. Fetch
    _requestText();
  }

  void _syncManagerToDisplay() {
    if (manager.currentBookId != displayBookId) {
      manager.onBookSelected(context, displayBookId);
    }
    manager.currentChapterNotifier.value = displayChapter;
  }

  void _requestText() {
    if (manager.isSinglePanelNotifier.value) return;
    manager.requestText();
  }

  void _scrollToVerse(int verse) {
    // Just jump, the scroll listener will update the UI when it arrives
    syncController.jumpToVerse(verse);
  }
}

/// Custom recognizer that listens only for scaling (pinch) gestures
class CustomScaleGestureRecognizer extends ScaleGestureRecognizer {
  CustomScaleGestureRecognizer({super.debugOwner});

  @override
  void rejectGesture(int pointer) {
    // Don't reject just because another gesture (e.g., scroll) won
    acceptGesture(pointer);
  }
}
