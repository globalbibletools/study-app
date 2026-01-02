import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  late int bookId;
  late int chapter;
  int verse = 1;

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
        centerTitle: false,
        titleSpacing: 0,
        title: ValueListenableBuilder<String>(
          valueListenable: manager.currentBookNotifier,
          builder: (context, bookName, _) {
            return ValueListenableBuilder<int>(
              valueListenable: manager.currentChapterNotifier,
              builder: (context, chapter, _) {
                return ReferenceChooser(
                  currentBookName: bookName,
                  currentBookId: manager.currentBookId,
                  currentChapter: chapter,
                  currentVerse: verse,
                  onBookSelected: (bookId) async {
                    manager.onBookSelected(context, bookId);
                    setState(() {
                      verse = 1;
                    });
                    _requestText();
                  },
                  onChapterSelected: (newChapter) {
                    manager.onChapterSelected(newChapter);
                    setState(() {
                      verse = 1;
                    });
                    _requestText();
                  },
                  onVerseSelected: (verse) {
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
    // If you need to trigger updates in the children widgets:
    setState(() {
      bookId = manager.currentBookId;
      chapter = manager.currentChapterNotifier.value;
    });

    // Original logic
    if (manager.isSinglePanelNotifier.value) return;
    manager.requestText();
  }

  void _scrollToVerse(int verse) {
    setState(() {
      this.verse = verse;
    });
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
