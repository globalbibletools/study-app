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
    if (textNotifier.value.isNotEmpty) return;
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
    required this.onScaleInteraction,
  });

  final int bookId;
  final int chapter;
  final HomeManager manager;
  final double fontScale;
  final void Function(double) onScaleChanged;
  final Future<void> Function(int wordId) showWordDetails;
  final VoidCallback onAdvancePage;
  final void Function(bool isEnabled) onScaleInteraction;

  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  final _pageManager = ChapterPageManager();
  final _scrollController = ScrollController();

  late final double _baseFontSize;
  late double _baseScale;
  late double _currentScale;
  double _gestureStartScale = 1.0;
  bool _isScalingInProgress = false;
  Alignment _transformAlignment = Alignment.center;
  bool _didDisablePageViewScroll = false;

  double get _fontSize => _baseFontSize * _baseScale;

  @override
  void initState() {
    super.initState();
    _pageManager.textNotifier.addListener(_onTextLoaded);
    _pageManager.loadChapter(widget.bookId, widget.chapter);
    _baseFontSize = widget.manager.baseFontSize;
    _baseScale = widget.fontScale;
    _currentScale = widget.fontScale;
  }

  void _onTextLoaded() {
    if (_pageManager.textNotifier.value.isNotEmpty) {
      _pageManager.textNotifier.removeListener(_onTextLoaded);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(_estimatedPopupHeight());
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChapterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fontScale != oldWidget.fontScale && !_isScalingInProgress) {
      setState(() {
        _baseScale = widget.fontScale;
        _currentScale = widget.fontScale;
      });
    }
  }

  @override
  void dispose() {
    _pageManager.dispose();
    _pageManager.textNotifier.removeListener(_onTextLoaded);
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
                  _isScalingInProgress = true;
                  _gestureStartScale = _baseScale;
                  _updateTransformAlignment(details.localFocalPoint);
                  _didDisablePageViewScroll = false;
                }
                ..onUpdate = (details) {
                  if (details.scale != 1.0 && !_didDisablePageViewScroll) {
                    widget.onScaleInteraction(false);
                    _didDisablePageViewScroll = true;
                  }
                  setState(() {
                    _currentScale = (_gestureStartScale * details.scale).clamp(
                      0.5,
                      3.0,
                    );
                  });
                }
                ..onEnd = (details) {
                  if (_didDisablePageViewScroll) {
                    widget.onScaleInteraction(true);
                  }
                  setState(() {
                    _baseScale = _currentScale;
                  });
                  _isScalingInProgress = false;
                  widget.onScaleChanged(_baseScale);
                  widget.onScaleInteraction(true);
                };
            },
          ),
    };
  }

  void _updateTransformAlignment(Offset localFocalPoint) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !_scrollController.hasClients) return;

    final viewportSize = renderBox.size;
    final scrollPosition = _scrollController.position;

    // This is the total height of the content inside the scroll view.
    final totalContentHeight =
        scrollPosition.maxScrollExtent + viewportSize.height;
    final totalContentSize = Size(viewportSize.width, totalContentHeight);

    // This adjusts the focal point by the current scroll offset to get its
    // position within the entire scrollable content, not just the visible part.
    final adjustedFocalPoint = Offset(
      localFocalPoint.dx,
      localFocalPoint.dy + scrollPosition.pixels,
    );

    setState(() {
      _transformAlignment = _calculateAlignment(
        totalContentSize,
        adjustedFocalPoint,
      );
    });
  }

  Alignment _calculateAlignment(Size widgetSize, Offset focalPoint) {
    final dx = focalPoint.dx.clamp(0.0, widgetSize.width);
    final dy = focalPoint.dy.clamp(0.0, widgetSize.height);
    return Alignment(
      (dx / widgetSize.width) * 2 - 1,
      (dy / widgetSize.height) * 2 - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.sizeOf(context).height - 200;
    return RawGestureDetector(
      gestures: _zoomGesture,
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Transform.scale(
            scale: _baseScale > 0 ? _currentScale / _baseScale : 1.0,
            alignment: _transformAlignment,
            child: ValueListenableBuilder<List<HebrewGreekWord>>(
              valueListenable: _pageManager.textNotifier,
              builder: (context, words, child) {
                if (words.isEmpty) {
                  return const SizedBox();
                }
                return Column(
                  children: [
                    SizedBox(height: _estimatedPopupHeight()),
                    HebrewGreekText(
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
                    ),
                    _buildNextChapterButton(),
                    SizedBox(height: bottomPadding),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _ensurePopupIsVisible(Rect popupRect) {
    if (!mounted || !_scrollController.hasClients) return;

    final RenderBox? scrollBox = context.findRenderObject() as RenderBox?;
    if (scrollBox == null) return;
    final contentTopGlobal = scrollBox.localToGlobal(Offset.zero).dy;
    const topPadding = 10.0;

    if (popupRect.top < contentTopGlobal) {
      final scrollAmount = contentTopGlobal - popupRect.top + topPadding;

      final newOffset = (_scrollController.offset - scrollAmount).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      _scrollController.animateTo(
        newOffset,
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
        child: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: tooltip,
            icon: Icon(Icons.arrow_forward),
            onPressed: widget.onAdvancePage,
          ),
        ),
      ),
    );
  }
}
