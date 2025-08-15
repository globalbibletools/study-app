import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/hebrew_greek_text.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/panel_manager.dart';
import 'package:studyapp/ui/home/home.dart';
import 'package:studyapp/ui/home/word_details_dialog/word_details_dialog.dart';

class ChapterPage extends StatefulWidget {
  const ChapterPage({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.manager,
  });

  final int bookId;
  final int chapter;
  final HebrewGreekPanelManager manager;

  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  late HebrewGreekPanelManager manager;

  final _textNotifier = ValueNotifier<List<HebrewGreekWord>>([]);

  late final double _baseFontSize;

  // The scale at the end of the last zoom gesture.
  late double _baseScale;

  // The current scale during a zoom gesture.
  late double _currentScale;

  // The scale at the beginning of the current zoom gesture.
  double _gestureStartScale = 1.0;

  // The alignment for the Transform.scale, calculated from the gesture's focal point.
  Alignment _transformAlignment = Alignment.center;

  // Computed font size based on the last committed scale.
  double get _fontSize => _baseFontSize * _baseScale;

  @override
  void initState() {
    super.initState();
    manager = widget.manager;
    _baseFontSize = manager.baseFontSize;
    _baseScale = manager.fontScaleNotifier.value;
    _currentScale = manager.fontScaleNotifier.value;

    widget.manager.fontScaleNotifier.addListener(_onFontScaleChanged);
    _loadChapterData();
  }

  @override
  void didUpdateWidget(covariant ChapterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This is crucial: If Flutter reuses this widget for a new chapter,
    // we must fetch the new chapter's data.
    if (widget.bookId != oldWidget.bookId ||
        widget.chapter != oldWidget.chapter) {
      _loadChapterData();
    }
  }

  Future<void> _loadChapterData() async {
    // Clear old data to show a loading state.
    _textNotifier.value = [];
    final words = await widget.manager.getChapterData(
      widget.bookId,
      widget.chapter,
    );
    if (mounted) {
      _textNotifier.value = words;
    }
  }

  @override
  void dispose() {
    widget.manager.fontScaleNotifier.removeListener(_onFontScaleChanged);
    _textNotifier.dispose();
    super.dispose();
  }

  void _onFontScaleChanged() {
    if (mounted) {
      final newScale = widget.manager.fontScaleNotifier.value;
      setState(() {
        _baseScale = newScale;
        _currentScale = newScale;
      });
    }
  }

  Map<Type, GestureRecognizerFactory<GestureRecognizer>> get _zoomGesture {
    return {
      ScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
            () => ScaleGestureRecognizer(),
            (ScaleGestureRecognizer instance) {
              instance
                ..onStart = (details) {
                  _gestureStartScale = _baseScale;
                  // Set the focal point for the zoom.
                  _updateTransformAlignment(details.localFocalPoint);
                }
                ..onUpdate = (details) {
                  setState(() {
                    // Update the current scale during the gesture.
                    _currentScale = (_gestureStartScale * details.scale).clamp(
                      0.5,
                      3.0,
                    );
                  });
                }
                ..onEnd = (details) {
                  setState(() {
                    // When the gesture ends, commit the new scale.
                    _baseScale = _currentScale;
                  });
                  // Save the new scale factor.
                  manager.saveFontScale(_baseScale);
                };
            },
          ),
    };
  }

  void _updateTransformAlignment(Offset localFocalPoint) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    setState(() {
      // Calculate the alignment based on the focal point and widget size.
      _transformAlignment = _calculateAlignment(
        renderBox.size,
        localFocalPoint,
      );
    });
  }

  Alignment _calculateAlignment(Size widgetSize, Offset focalPoint) {
    // Clamp the focal point to be within the widget's bounds.
    final dx = focalPoint.dx.clamp(0.0, widgetSize.width);
    final dy = focalPoint.dy.clamp(0.0, widgetSize.height);

    // Convert the screen coordinate to an Alignment value between -1.0 and 1.0.
    return Alignment(
      (dx / widgetSize.width) * 2 - 1,
      (dy / widgetSize.height) * 2 - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: _zoomGesture,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0),
        child: Transform.scale(
          scale: _baseScale > 0 ? _currentScale / _baseScale : 1.0,
          alignment: _transformAlignment,
          child: ValueListenableBuilder<List<HebrewGreekWord>>(
            valueListenable: _textNotifier,
            builder: (context, words, child) {
              if (words.isEmpty) {
                return const SizedBox();
              }
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    '${widget.bookId} ${widget.chapter}',
                    style: TextStyle(fontSize: 30),
                  ),
                  const SizedBox(height: 10),
                  HebrewGreekText(
                    words: words,
                    textDirection: manager.isRtl(widget.bookId)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    textStyle: TextStyle(fontSize: _fontSize),
                    verseNumberStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: _fontSize * 0.7,
                    ),
                    popupBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.inverseSurface,
                    popupTextStyle: TextStyle(
                      fontFamily: 'sbl',
                      fontSize: _fontSize * 0.7,
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
                    popupWordProvider: (wordId) {
                      final locale = Localizations.localeOf(context);
                      return manager.getPopupTextForId(
                        locale,
                        wordId,
                        _showDownloadDialog,
                      );
                    },
                    onWordLongPress: _showWordDetails,
                  ),
                ],
              );
            },
          ),
        ),
      ),
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
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(DownloadDialogChoice.useEnglish),
                ),
                FilledButton(
                  child: Text(l10n.download),
                  onPressed: () =>
                      Navigator.of(context).pop(DownloadDialogChoice.download),
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

  Future<void> _showWordDetails(int wordId) async {
    await showDialog(
      context: context,
      builder: (context) => WordDetailsDialog(
        wordId: wordId,
        isRtl: manager.isRtl(widget.bookId),
      ),
    );
  }
}
