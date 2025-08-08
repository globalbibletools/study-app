import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/ui/home/hebrew_greek_text.dart';
import 'package:studyapp/ui/home/home_manager.dart';
import 'package:studyapp/ui/home/home.dart';

// Manages the data for a single chapter page.
class ChapterPageManager {
  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();
  final textNotifier = ValueNotifier<List<HebrewGreekWord>>([]);

  Future<void> loadChapter(int bookId, int chapter) async {
    textNotifier.value = await _hebrewGreekDb.getChapter(bookId, chapter);
  }

  void dispose() {
    textNotifier.dispose();
  }
}

class ChapterPage extends StatefulWidget {
  const ChapterPage({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.manager,
    required this.fontScale,
    required this.onScaleChanged,
    required this.showWordDetails,
    required this.onAdvancePage,
  });

  final int bookId;
  final int chapter;
  final HomeManager manager;
  final double fontScale;
  final void Function(double) onScaleChanged;
  final void Function(int wordId) showWordDetails;
  final VoidCallback onAdvancePage;

  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  final _pageManager = ChapterPageManager();
  final _scrollController = ScrollController();

  late final double _baseFontSize;
  double _baseScale = 1.0;
  double _gestureScale = 1.0;
  bool get _isScaling => _gestureScale != 1.0;
  double get _fontSize => _baseFontSize * _baseScale;

  @override
  void initState() {
    super.initState();
    _pageManager.loadChapter(widget.bookId, widget.chapter);
    _baseFontSize = widget.manager.baseFontSize;
    _baseScale = widget.fontScale;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_estimatedPopupHeight());
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChapterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fontScale != oldWidget.fontScale && !_isScaling) {
      _baseScale = widget.fontScale;
    }
  }

  @override
  void dispose() {
    _pageManager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double _estimatedPopupHeight() {
    return _fontSize * 2;
  }

  Map<Type, GestureRecognizerFactory<GestureRecognizer>> get _zoomGesture {
    return {
      CustomScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<CustomScaleGestureRecognizer>(
            () => CustomScaleGestureRecognizer(),
            (CustomScaleGestureRecognizer instance) {
              instance
                ..onStart = (details) {
                  setState(() => _gestureScale = _baseScale);
                }
                ..onUpdate = (details) {
                  setState(
                    () =>
                        _gestureScale = (details.scale * _baseScale).clamp(
                          0.5,
                          3.0,
                        ),
                  );
                }
                ..onEnd = (details) {
                  setState(() => _baseScale = _gestureScale);
                  widget.onScaleChanged(_baseScale);
                };
            },
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: _zoomGesture,
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Transform.scale(
            scale: _isScaling ? _gestureScale / _baseScale : 1.0,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                SizedBox(height: _estimatedPopupHeight()),
                ValueListenableBuilder<List<HebrewGreekWord>>(
                  valueListenable: _pageManager.textNotifier,
                  builder: (context, words, child) {
                    if (words.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return HebrewGreekText(
                      words: words,
                      textDirection:
                          widget.manager.isRtl(widget.bookId)
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                      textStyle: TextStyle(fontSize: _fontSize),
                      verseNumberStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: _fontSize * 0.7,
                      ),
                      popupBackgroundColor:
                          Theme.of(context).colorScheme.inverseSurface,
                      popupTextStyle: TextStyle(
                        fontFamily: 'sbl',
                        fontSize: _fontSize * 0.7,
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                      popupWordProvider: (wordId) {
                        final locale = Localizations.localeOf(context);
                        return widget.manager.getPopupTextForId(locale, wordId);
                      },
                      onPopupShown: _ensurePopupIsVisible,
                      onWordLongPress: widget.showWordDetails,
                    );
                  },
                ),
                _buildNextChapterButton(),
                const SizedBox(height: 300.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _ensurePopupIsVisible(Rect popupRect) {
    if (!mounted || !_scrollController.hasClients) return;
    final topSafeArea = MediaQuery.of(context).padding.top;
    final appBarHeight = AppBar().preferredSize.height;
    final topBarHeight = topSafeArea + appBarHeight;

    if (popupRect.top < topBarHeight) {
      final scrollAmount = topBarHeight - popupRect.top;
      final newOffset = (_scrollController.offset - scrollAmount).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
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

  Widget _buildNextChapterButton() {
    final bool isRtl = widget.manager.isRtl(widget.bookId);
    final alignment = isRtl ? Alignment.centerLeft : Alignment.centerRight;
    final tooltip = AppLocalizations.of(context)!.nextChapter;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: IconButton(
          iconSize: 48,
          tooltip: tooltip,
          icon: Icon(Icons.arrow_forward),
          onPressed: widget.onAdvancePage,
        ),
      ),
    );
  }
}
