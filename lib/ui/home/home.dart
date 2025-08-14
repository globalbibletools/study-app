import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/home/chapter_page.dart';
import 'package:studyapp/ui/home/drawer.dart';
import 'package:studyapp/ui/home/word_details_dialog/word_details_dialog.dart';

import 'book_chooser.dart';
import 'bible_panel/bible_text.dart';
import 'home_manager.dart';

enum DownloadDialogChoice { useEnglish, download }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final manager = HomeManager();
  double _fontScale = 1.0;

  late int bookId;
  late int chapter;

  @override
  void initState() {
    super.initState();
    manager.onGlossDownloadNeeded = _showDownloadDialog;

    final (initialBook, initialChapter) = manager.getInitialBookAndChapter();
    bookId = initialBook;
    chapter = initialChapter;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager.init(context);
    _fontScale = manager.getFontScale();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            OutlinedButton(
              onPressed: _showBookChooserDialog,
              child: ValueListenableBuilder<String>(
                valueListenable: manager.currentBookNotifier,
                builder: (context, value, child) => Text(value),
              ),
            ),
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
            _fontScale = manager.getFontScale();
          });
        },
      ),
      body: Column(
        children: [
          Expanded(child: _buildHebrewGreekView()),
          ValueListenableBuilder<bool>(
            valueListenable: manager.isSinglePanelNotifier,
            builder: (context, isSinglePanel, child) {
              if (isSinglePanel) return const SizedBox();
              return Expanded(child: _buildBibleView());
            },
          ),
        ],
      ),
    );
  }

  List<int> top = <int>[];
  List<int> bottom = <int>[0];

  Widget _buildHebrewGreekView() {
    const centerKey = ValueKey<String>('bottom-sliver-list');
    return CustomScrollView(
      center: centerKey,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate((
            BuildContext context,
            int index,
          ) {
            return ChapterPage(
              key: ValueKey('$bookId-$chapter'),
              bookId: bookId,
              chapter: chapter,
              manager: manager,
              fontScale: _fontScale,
              onScaleChanged: (newScale) {
                setState(() {
                  _fontScale = newScale;
                  manager.saveFontScale(newScale);
                });
              },
              showWordDetails: _showWordDetails,
            );
          }, childCount: 1),
        ),
        SliverList(
          key: centerKey,
          delegate: SliverChildBuilderDelegate((
            BuildContext context,
            int index,
          ) {
            return ChapterPage(
              key: ValueKey('$bookId-$chapter'),
              bookId: bookId,
              chapter: chapter,
              manager: manager,
              fontScale: _fontScale,
              onScaleChanged: (newScale) {
                setState(() {
                  _fontScale = newScale;
                  manager.saveFontScale(newScale);
                });
              },
              showWordDetails: _showWordDetails,
            );
          }, childCount: 1),
        ),
      ],
    );
  }

  void _requestText() {
    if (manager.isSinglePanelNotifier.value) return;
    print('requesting text');
    manager.requestText(
      textColor: Theme.of(context).textTheme.bodyMedium!.color!,
      footnoteColor: Theme.of(context).primaryColor,
    );
  }

  Future<void> _showDownloadDialog(Locale locale) async {
    final l10n = AppLocalizations.of(context)!;
    final choice =
        await showDialog<DownloadDialogChoice>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Text(l10n.downloadGlossesMessage),
              actions: <Widget>[
                TextButton(
                  child: Text(l10n.useEnglish),
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pop(DownloadDialogChoice.useEnglish),
                ),
                FilledButton(
                  child: Text(l10n.download),
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pop(DownloadDialogChoice.download),
                ),
              ],
            );
          },
        ) ??
        DownloadDialogChoice.useEnglish;

    if (!mounted) return;

    if (choice == DownloadDialogChoice.useEnglish) {
      await manager.setLanguageToEnglish(locale);
    } else {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.downloadingGlossesMessage),
          duration: const Duration(seconds: 30),
        ),
      );
      try {
        await manager.downloadGlosses(locale);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadComplete)));
      } catch (e) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadFailed)));
      }
    }
  }

  Future<void> _showBookChooserDialog() async {
    manager.chapterCountNotifier.value = null;
    final selectedIndex = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => const BookChooser(),
    );
    if (mounted) {
      manager.onBookSelected(context, selectedIndex);
    }
  }

  Future<void> _showWordDetails(int wordId) async {
    await showDialog(
      context: context,
      builder:
          (context) =>
              WordDetailsDialog(wordId: wordId, isRtl: manager.isRtl(bookId)),
    );
  }

  Widget _buildBibleView() {
    return Expanded(
      child: ValueListenableBuilder<TextParagraph>(
        valueListenable: manager.textParagraphNotifier,
        builder: (context, paragraph, child) {
          return Container(
            width: double.infinity,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: BibleText(paragraphs: paragraph, paragraphSpacing: 10.0),
              ),
            ),
          );
        },
      ),
    );
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
