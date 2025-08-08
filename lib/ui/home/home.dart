import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/home/chapter_page.dart';
import 'package:studyapp/ui/home/drawer.dart';
import 'package:studyapp/ui/home/word_details_dialog/word_details_dialog.dart';

import 'book_chooser.dart';
import 'chapter_chooser.dart';
import 'home_manager.dart';

enum DownloadDialogChoice { useEnglish, download }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final manager = HomeManager();
  late final PageController _pageController;
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    manager.onGlossDownloadNeeded = _showDownloadDialog;

    final (initialBook, initialChapter) = manager.getInitialBookAndChapter();
    final initialPageIndex = manager.pageIndexForBookAndChapter(
      initialBook,
      initialChapter,
    );
    _pageController = PageController(initialPage: initialPageIndex);

    _pageController.addListener(() {
      final currentPage = _pageController.page?.round() ?? initialPageIndex;
      final currentBookChapter = manager.bookAndChapterForPageIndex(
        currentPage,
      );
      if (currentBookChapter.$2 != manager.currentChapterNotifier.value) {
        manager.onPageChanged(context, currentPage);
      }
    });

    manager.pageJumpNotifier.addListener(() {
      final page = manager.pageJumpNotifier.value;
      if (page != null && page != _pageController.page?.round()) {
        _pageController.jumpToPage(page);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager.init(context);
    _fontScale = manager.getFontScale();
  }

  @override
  void dispose() {
    _pageController.dispose();
    manager.pageJumpNotifier.dispose();
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
              onPressed: manager.showChapterChooser,
              child: ValueListenableBuilder(
                valueListenable: manager.currentChapterNotifier,
                builder: (context, value, child) => Text('$value'),
              ),
            ),
          ],
        ),
      ),
      drawer: AppDrawer(
        onSettingsClosed: () {
          setState(() {
            _fontScale = manager.getFontScale();
          });
        },
      ),
      body: Stack(children: [_buildPageView(), _buildChapterChooser()]),
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: HomeManager.totalChapters,
      itemBuilder: (context, index) {
        final (bookId, chapter) = manager.bookAndChapterForPageIndex(index);
        return ChapterPage(
          key: ValueKey(
            '$bookId-$chapter',
          ), // Ensures correct state is maintained
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
      },
    );
  }

  // The rest of the methods from the original HomeScreen remain below
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

  ValueListenableBuilder<int?> _buildChapterChooser() {
    return ValueListenableBuilder<int?>(
      valueListenable: manager.chapterCountNotifier,
      builder: (context, chapterCount, child) {
        if (chapterCount == null) return const SizedBox();
        return ChapterChooser(
          chapterCount: chapterCount,
          onChapterSelected: manager.onChapterSelected,
        );
      },
    );
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
    final pageIndex = _pageController.page!.round();
    final (bookId, _) = manager.bookAndChapterForPageIndex(pageIndex);
    showDialog(
      context: context,
      builder:
          (context) =>
              WordDetailsDialog(wordId: wordId, isRtl: manager.isRtl(bookId)),
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
