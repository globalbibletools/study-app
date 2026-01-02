import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/bible_panel/bible_panel.dart';
import 'package:studyapp/ui/home/drawer.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/panel.dart';

import 'bible_nav_bar.dart';
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

  late int bookId;
  late int chapter;

  @override
  void initState() {
    super.initState();

    final (initialBook, initialChapter) = manager.getInitialBookAndChapter();
    bookId = initialBook;
    chapter = initialChapter;
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
        title: ValueListenableBuilder<String>(
          valueListenable: manager.currentBookNotifier,
          builder: (context, bookName, _) {
            return ValueListenableBuilder<int>(
              valueListenable: manager.currentChapterNotifier,
              builder: (context, chapter, _) {
                return BibleNavBar(
                  currentBookName: bookName,
                  currentBookId: manager
                      .currentBookId, // Make sure to add getter in HomeManager
                  currentChapter: chapter,
                  onBookSelected: (id) async {
                    // Navigate to Book 1, Chapter 1 of selected book
                    // manager.onBookSelected(context, id); // You might need to expose this logic
                  },
                  onChapterSelected: (newChapter) {
                    manager.currentChapterNotifier.value = newChapter;
                    _requestText();
                  },
                  onVerseSelected: (verse) {
                    // Scroll logic
                    _scrollToVerse(verse);
                  },
                );
              },
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              manager.togglePanelState();
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
              bookId: bookId,
              chapter: chapter,
              // showWordDetails: _showWordDetails,
              syncController: syncController,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: manager.isSinglePanelNotifier,
            builder: (context, isSinglePanel, child) {
              if (isSinglePanel) return const SizedBox();
              return Expanded(
                child: BiblePanel(
                  bookId: bookId,
                  chapter: chapter,
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

  void _requestText() {
    if (manager.isSinglePanelNotifier.value) return;
    print('requesting text');
    manager.requestText();
  }

  void _scrollToVerse(int verse) {
    // This logic depends heavily on how your Panels render the text.
    // Assuming syncController can handle a "goto" request:
    // syncController.scrollToVerse(verse);

    // OR, if you don't have that method, you might need to find the item index.
    // For now, let's print as placeholder if the implementation is missing:
    print("Navigating to Verse: $verse");
  }

  // Future<void> _showBookChooserDialog() async {
  //   // manager.chapterCountNotifier.value = null;
  //   // final selectedIndex = await showDialog<int>(
  //   //   context: context,
  //   //   builder: (BuildContext context) => const BookChooser(),
  //   // );
  //   // if (mounted) {
  //   //   manager.onBookSelected(context, selectedIndex);
  //   // }
  // }
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
