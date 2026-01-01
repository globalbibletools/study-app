import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/bible_panel/bible_panel.dart';
import 'package:studyapp/ui/home/drawer.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/panel.dart';

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
        title: Row(
          children: [
            // OutlinedButton(
            //   onPressed: _showBookChooserDialog,
            //   child: ValueListenableBuilder<String>(
            //     valueListenable: manager.currentBookNotifier,
            //     builder: (context, value, child) => Text(value),
            //   ),
            // ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  top.add(-top.length - 1);
                  bottom.add(bottom.length);
                });
              },
              child: ValueListenableBuilder(
                valueListenable: manager.currentChapterNotifier,
                builder: (context, value, child) => Text('$value'),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              manager.togglePanelState();
              _requestText();
            },
            icon: Icon(Icons.splitscreen),
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

  // Widget _buildBibleView() {
  //   return Expanded(
  //     child: BiblePanel(bookId: bookId, chapter: chapter),
  //   );
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
