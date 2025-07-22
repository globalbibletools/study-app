import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/home/drawer.dart';
import 'package:studyapp/home/hebrew_greek_text.dart';
import 'package:studyapp/home/word_details_dialog/word_details_dialog.dart';
import 'package:studyapp/l10n/app_localizations.dart';

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
  final _scrollController = ScrollController();

  // Pinch to zoom font scaling
  static const double _baseFontSize = 20.0;
  double _baseScale = 1.0;
  double _gestureScale = 1.0;
  bool get _isScaling => _gestureScale != 1.0;

  double get _fontSize => _baseFontSize * _baseScale;

  @override
  void initState() {
    super.initState();
    manager.onGlossDownloadNeeded = _showDownloadDialog;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager.init(context);
    manager.onTextUpdated = _scrollToTop;
    _baseScale = manager.getFontScale();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_estimatedPopupHeight());
    }
  }

  double _estimatedPopupHeight() {
    return _fontSize * 2;
  }

  void _ensurePopupIsVisible(Rect popupRect) {
    if (!mounted || !_scrollController.hasClients) return;

    final topSafeArea = MediaQuery.of(context).padding.top;
    final appBarHeight = AppBar().preferredSize.height;
    final topBarHeight = topSafeArea + appBarHeight;

    if (popupRect.top < topBarHeight) {
      // Amount the popup is obscured by the app bar and safe area.
      final scrollAmount = topBarHeight - popupRect.top;
      // We scroll down, which means decreasing the scroll offset.
      final newOffset = (_scrollController.offset - scrollAmount).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      // Scroll a little bit more to have some padding.
      final finalOffset = (newOffset - 10.0).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      _scrollController.animateTo(
        finalOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
                builder: (context, value, child) {
                  return Text(value);
                },
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: manager.showChapterChooser,
              child: ValueListenableBuilder(
                valueListenable: manager.currentChapterNotifier,
                builder: (context, value, child) {
                  return Text('$value');
                },
              ),
            ),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          RawGestureDetector(
            gestures: _zoomGesture,
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: Transform.scale(
                  scale: _isScaling ? _gestureScale : 1.0,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      SizedBox(height: _estimatedPopupHeight()),
                      _buildText(),
                      const SizedBox(height: 300.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildChapterChooser(),
        ],
      ),
    );
  }

  Map<Type, GestureRecognizerFactory<GestureRecognizer>> get _zoomGesture {
    return {
      CustomScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<CustomScaleGestureRecognizer>(
            () => CustomScaleGestureRecognizer(),
            (CustomScaleGestureRecognizer instance) {
              instance
                ..onStart = (details) {
                  _gestureScale = 1.0;
                }
                ..onUpdate = (details) {
                  setState(() {
                    _gestureScale = details.scale.clamp(0.5, 3.0);
                  });
                }
                ..onEnd = (details) {
                  setState(() {
                    _baseScale = (_baseScale * _gestureScale).clamp(0.5, 3.0);
                    _gestureScale = 1.0;
                    manager.saveFontScale(_baseScale);
                  });
                };
            },
          ),
    };
  }

  ValueListenableBuilder<List<HebrewGreekWord>> _buildText() {
    return ValueListenableBuilder(
      valueListenable: manager.textNotifier,
      builder: (context, words, child) {
        return HebrewGreekText(
          words: words,
          textDirection:
              manager.currentChapterIsRtl
                  ? TextDirection.rtl
                  : TextDirection.ltr,
          textStyle: TextStyle(fontFamily: 'sbl', fontSize: _fontSize),
          verseNumberStyle: TextStyle(
            fontFamily: 'sbl',
            color: Theme.of(context).colorScheme.primary,
            fontSize: _fontSize * 0.7,
          ),
          popupBackgroundColor: Theme.of(context).colorScheme.inverseSurface,
          popupTextStyle: TextStyle(
            fontFamily: 'sbl',
            fontSize: _fontSize,
            color: Theme.of(context).colorScheme.onInverseSurface,
          ),
          popupWordProvider: (wordId) {
            final locale = Localizations.localeOf(context);
            return manager.getPopupTextForId(locale, wordId);
          },
          onPopupShown: _ensurePopupIsVisible,
          onWordLongPress: _showWordDetails,
        );
      },
    );
  }

  ValueListenableBuilder<int?> _buildChapterChooser() {
    return ValueListenableBuilder<int?>(
      valueListenable: manager.chapterCountNotifier,
      builder: (context, chapterCount, child) {
        if (chapterCount == null) {
          return const SizedBox();
        }
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
      builder: (BuildContext context) {
        return const BookChooser();
      },
    );
    if (mounted) {
      manager.onBookSelected(context, selectedIndex);
    }
  }

  Future<void> _showWordDetails(int wordId) async {
    showDialog(
      context: context,
      builder:
          (context) => WordDetailsDialog(
            wordId: wordId,
            fontSize: _fontSize,
            isRtl: manager.currentChapterIsRtl,
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
