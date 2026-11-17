import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gbt/common/book_name.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/common/word.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/resources/resource.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/panel_area/common/verse_sync_layout.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';
import 'package:gbt/ui/home/panel_area/hebrew_greek_panel/chapter_manager.dart';
import 'package:gbt/ui/home/panel_area/hebrew_greek_panel/text.dart';

class VerseNumberTapNotification extends Notification {
  final int bookId;
  final int chapter;
  final int verse;

  const VerseNumberTapNotification({
    required this.bookId,
    required this.chapter,
    required this.verse,
  });
}

/// Manages fetching data and alerts for a single chapter.
class HebrewGreekChapter extends StatefulWidget {
  const HebrewGreekChapter({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.fontSize,
    required this.verseLayout,
    required this.readingModeEnabled,
    required this.highlightNotifier,
    this.navigationViewModel,
    this.onReadingCheckboxGuideRectChanged,
    this.onReadingCheckboxGuideCompleted,
  });

  final int bookId;
  final int chapter;
  final double fontSize;
  final VerseLayout verseLayout;
  final bool readingModeEnabled;
  final NavigationViewModel? navigationViewModel;
  final ValueChanged<Rect?>? onReadingCheckboxGuideRectChanged;
  final VoidCallback? onReadingCheckboxGuideCompleted;
  final ValueNotifier<Reference?> highlightNotifier;

  @override
  State<HebrewGreekChapter> createState() => HebrewGreekChapterState();
}

class HebrewGreekChapterState extends State<HebrewGreekChapter> {
  final manager = HebrewGreekChapterManager();

  final _textController = HebrewGreekTextController();

  // GlobalKey to track the HebrewGreekText widget's position relative to the HebrewGreekChapter
  final _hebrewGreekTextKey = GlobalKey();

  // Keyed so the chapter title can be measured and attributed to verse 1.
  final _titleKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    manager.loadChapterData(widget.bookId, widget.chapter);

    if (widget.readingModeEnabled) {
      manager.loadReadVerses(widget.bookId, widget.chapter);
    }

    _textController.setSpotlightUpdatedCalllback(
      _reportReadingCheckboxGuideRect,
    );
    _textController.setGeometryChangedCallback(_publishGeometry);
  }

  void _publishGeometry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ChapterGeometryChangedNotification(
        bookId: widget.bookId,
        chapter: widget.chapter,
        geometry: _computeGeometry(),
      ).dispatch(context);
    });
  }

  @override
  void didUpdateWidget(covariant HebrewGreekChapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If Flutter reuses this widget for a new chapter, fetch the new chapter's data.
    if (widget.bookId != oldWidget.bookId ||
        widget.chapter != oldWidget.chapter) {
      manager.loadChapterData(widget.bookId, widget.chapter);

      if (widget.readingModeEnabled) {
        manager.loadReadVerses(widget.bookId, widget.chapter);
      }
    } else if (widget.readingModeEnabled && !oldWidget.readingModeEnabled) {
      manager.loadReadVerses(widget.bookId, widget.chapter);
    }
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  ChapterGeometry? _computeGeometry() {
    if (manager.textNotifier.value.isEmpty) return null;

    final textGeometry = _textController.geometry;
    if (textGeometry == null) return null;

    final textRenderBox =
        _hebrewGreekTextKey.currentContext?.findRenderObject() as RenderBox?;
    final chapterRenderBox = context.findRenderObject() as RenderBox?;
    if (textRenderBox == null ||
        chapterRenderBox == null ||
        !chapterRenderBox.hasSize) {
      return null;
    }

    final textTopLeftInChapter = textRenderBox.localToGlobal(
      Offset.zero,
      ancestor: chapterRenderBox,
    );
    final dy = textTopLeftInChapter.dy;

    final translated = textGeometry.translated(dy);

    final headings = <HeadingRect>[];
    final titleBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (titleBox != null && titleBox.attached && titleBox.hasSize) {
      final top = titleBox
          .localToGlobal(Offset.zero, ancestor: chapterRenderBox)
          .dy;
      headings.add(HeadingRect(top: top, bottom: top + titleBox.size.height));
    }

    return buildGeometry(
      spans: translated.spans,
      headings: headings,
      height: chapterRenderBox.size.height,
    );
  }

  ValueNotifier<String?>? get _flashedWordIdNotifier {
    if (getIt.isRegistered<HomeManager>()) {
      return getIt<HomeManager>().flashedWordIdNotifier;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager.verseCheckboxNotifier,
      builder: (context, child) {
        final checkedVerses = manager.verseCheckboxNotifier.value;
        final changedVerse = manager.verseCheckboxNotifier.changedVerse;
        final resetCheckedVerses = manager.verseCheckboxNotifier.resetAll;
        final checkedVersesRevision = manager.verseCheckboxNotifier.revision;
        return ValueListenableBuilder<List<HebrewGreekWord>>(
          valueListenable: manager.textNotifier,
          builder: (context, words, child) {
            if (words.isEmpty) return const SizedBox();

            return ValueListenableBuilder<Reference?>(
              valueListenable: widget.highlightNotifier,
              builder: (context, reference, _) {
                int? verseToHighlight;
                if (reference != null &&
                    reference.bookId == widget.bookId &&
                    reference.chapter == widget.chapter) {
                  verseToHighlight = reference.verse;
                }

                //always show first verse only (basic logic)
                final spotlightVerse =
                    widget.onReadingCheckboxGuideRectChanged != null ? 1 : null;

                Widget textWidget(String? flashedWordId) => HebrewGreekText(
                  key: _hebrewGreekTextKey,
                  words: words,
                  verseLayout: widget.verseLayout,
                  readingModeEnabled: widget.readingModeEnabled,
                  checkedVerses: checkedVerses,
                  changedCheckedVerse: changedVerse,
                  resetCheckedVerses: resetCheckedVerses,
                  checkedVersesRevision: checkedVersesRevision,
                  spotlightVerse: spotlightVerse,
                  controller: _textController,
                  textDirection: manager.isRtl(widget.bookId)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  textStyle: TextStyle(fontSize: widget.fontSize),
                  verseNumberStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: widget.fontSize * 0.7,
                  ),
                  onVerseNumberTap: (verse) {
                    VerseNumberTapNotification(
                      bookId: widget.bookId,
                      chapter: widget.chapter,
                      verse: verse,
                    ).dispatch(context);
                  },
                  onVerseCheckboxTap: (verse) async {
                    if (widget.onReadingCheckboxGuideCompleted != null) {
                      widget.onReadingCheckboxGuideCompleted!.call();
                      return;
                    }

                    final state = checkedVerses[verse];
                    await manager.setVerseRead(
                      VerseReadOptions(
                        bookId: widget.bookId,
                        chapter: widget.chapter,
                        verse: verse,
                        read: !(state?.readThisSession ?? false),
                      ),
                    );
                  },
                  onVerseNumberLongPress: (verse) {
                    _copyVerseToClipboard(context, verse);
                  },
                  popupBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.inverseSurface,
                  popupTextStyle: TextStyle(
                    fontFamily: 'sbl',
                    fontSize: widget.fontSize * 0.7,
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                  popupWordProvider: (wordId) {
                    return manager.getPopupTextForId(
                      wordId,
                      (langCode) => _handleMissingGloss(langCode),
                    );
                  },
                  onPopupShown: _ensurePopupIsVisible,
                  onWordLongPress: _showWordDetails,
                  flashedWordId: flashedWordId,
                  highlightedVerse: verseToHighlight,
                  highlightColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.25),
                );

                final flashNotifier = _flashedWordIdNotifier;
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        key: _titleKey,
                        '${bookNameForId(context, widget.bookId)} ${widget.chapter}',
                        style: TextStyle(fontSize: 30),
                      ),
                      const SizedBox(height: 10),
                      flashNotifier != null
                          ? ValueListenableBuilder<String?>(
                              valueListenable: flashNotifier,
                              builder: (context, flashedWordId, _) =>
                                  textWidget(flashedWordId),
                            )
                          : textWidget(null),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _ensurePopupIsVisible(Rect globalPopupRect) {
    // 1. Calculate the safe area top (Status Bar + App Bar + small padding)
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double safeTopPadding = statusBarHeight + kToolbarHeight + 16.0;

    final topY = globalPopupRect.top;

    // 2. If the top of the popup is underneath the App Bar
    if (topY < safeTopPadding) {
      final double scrollAdjustment = safeTopPadding - topY;
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) {
        return;
      }
      final position = scrollable.position;

      // Push the screen DOWN by decreasing the offset
      final targetOffset = position.pixels - scrollAdjustment;
      final clampedOffset = targetOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );

      if (position.pixels != clampedOffset) {
        position.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _reportReadingCheckboxGuideRect(Rect? localRect) {
    if (!mounted ||
        !widget.readingModeEnabled ||
        localRect == null ||
        widget.onReadingCheckboxGuideRectChanged == null) {
      return;
    }

    final textRenderBox =
        _hebrewGreekTextKey.currentContext?.findRenderObject() as RenderBox?;

    if (textRenderBox == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final globalTopLeft = textRenderBox.localToGlobal(localRect.topLeft);
      widget.onReadingCheckboxGuideRectChanged?.call(
        globalTopLeft & localRect.size,
      );
    });
  }

  Future<void> _handleMissingGloss(String langCode) async {
    // Use the shared helper logic
    final success = await ResourceUIHelper.ensureResource(
      context,
      ResourceType.gloss,
      langCode,
    );

    if (!success && mounted) {
      // If they clicked "Cancel" or download failed,
      // tell the manager to stop trying to load localized glosses
      // for this session so they aren't prompted on every single tap.
      manager.unsetGlossLang();
    } else if (success && mounted) {
      // Refresh the UI so the words show the newly downloaded glosses
      setState(() {});
    }
  }

  Future<void> _showWordDetails(String wordId) async {
    getIt<HomeManager>().startWordStudy(
      wordId: wordId,
      isRtl: manager.isRtl(widget.bookId),
    );
  }

  void _copyVerseToClipboard(BuildContext context, int verse) {
    final text = manager.getVerseText(verse);
    if (text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.verseCopied),
        duration: Durations.extralong1,
      ),
    );
  }
}
