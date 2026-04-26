import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyapp/common/book_name.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';
import 'package:studyapp/ui/common/resource_ui_helper.dart';
import 'package:studyapp/services/settings/user_settings.dart';
import 'package:studyapp/ui/home/panel_area/common/infinite_scroll_view.dart';
import 'package:studyapp/ui/home/common/scroll_sync_controller.dart';
import 'package:studyapp/ui/home/panel_area/hebrew_greek_panel/chapter_manager.dart';
import 'package:studyapp/ui/home/panel_area/hebrew_greek_panel/text.dart';
import 'package:studyapp/ui/home/word_details_dialog/word_details_dialog.dart';

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
    this.syncController,
  });

  final int bookId;
  final int chapter;
  final double fontSize;
  final VerseLayout verseLayout;
  final bool readingModeEnabled;
  final ScrollSyncController? syncController;

  @override
  State<HebrewGreekChapter> createState() => HebrewGreekChapterState();
}

class HebrewGreekChapterState extends State<HebrewGreekChapter>
    with VerseScrollable {
  final manager = HebrewGreekChapterManager();

  final _textController = HebrewGreekTextController();

  // GlobalKey to track the HebrewGreekText widget's position relative to the HebrewGreekChapter
  final _hebrewGreekTextKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    manager.loadChapterData(widget.bookId, widget.chapter);

    if (widget.readingModeEnabled) {
      manager.loadReadVerses(widget.bookId, widget.chapter);
    }
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

  @override
  double? getOffsetForVerse(int verseNumber) {
    // If Verse 1 is requested, return 0.0 to show the Chapter Header (Title).
    if (verseNumber == 1) {
      return 0.0;
    }

    final textLocalRect = _textController.getVerseRect(verseNumber);
    if (textLocalRect == null) return null;

    // Calculate the offset relative to the Chapter widget (context)
    // We need to add the height of the Header (Text + SizedBoxes)
    final textRenderBox =
        _hebrewGreekTextKey.currentContext?.findRenderObject() as RenderBox?;
    final chapterRenderBox = context.findRenderObject() as RenderBox?;

    if (textRenderBox != null && chapterRenderBox != null) {
      // Find where the Text widget starts inside the Chapter widget
      final textTopLeftInChapter = textRenderBox.localToGlobal(
        Offset.zero,
        ancestor: chapterRenderBox,
      );

      // Add that starting Y to the verse's local Y
      return textTopLeftInChapter.dy + textLocalRect.top;
    }

    // Fallback (if layout isn't ready, though it usually is when calling this)
    return textLocalRect.top;
  }

  @override
  int? getVerseForOffset(double yOffset) {
    // Convert the Chapter Y offset back to Text widget local Y
    final textRenderBox =
        _hebrewGreekTextKey.currentContext?.findRenderObject() as RenderBox?;
    final chapterRenderBox = context.findRenderObject() as RenderBox?;

    if (textRenderBox != null && chapterRenderBox != null) {
      final textTopLeftInChapter = textRenderBox.localToGlobal(
        Offset.zero,
        ancestor: chapterRenderBox,
      );

      // Subtract the header height to get "y" relative to the Text widget
      final localY = yOffset - textTopLeftInChapter.dy;

      return _textController.getVerseForOffset(localY);
    }

    return _textController.getVerseForOffset(yOffset);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager.verseCheckboxNotifier,
      builder: (context, child) {
        final checkedVerses = manager.verseCheckboxNotifier.value;
        return ValueListenableBuilder<List<HebrewGreekWord>>(
          valueListenable: manager.textNotifier,
          builder: (context, words, child) {
            if (words.isEmpty) return const SizedBox();

            return ValueListenableBuilder<VerseHighlight?>(
              valueListenable:
                  widget.syncController?.highlightNotifier ??
                  ValueNotifier(null),
              builder: (context, highlightInfo, _) {
                int? verseToHighlight;
                if (highlightInfo != null &&
                    highlightInfo.bookId == widget.bookId &&
                    highlightInfo.chapter == widget.chapter) {
                  verseToHighlight = highlightInfo.verse;
                }
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        '${bookNameForId(context, widget.bookId)} ${widget.chapter}',
                        style: TextStyle(fontSize: 30),
                      ),
                      const SizedBox(height: 10),
                      HebrewGreekText(
                        key: _hebrewGreekTextKey,
                        words: words,
                        verseLayout: widget.verseLayout,
                        readingModeEnabled: widget.readingModeEnabled,
                        checkedVerses: checkedVerses,
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
                        onVerseCheckboxTap: (verse) {
                          int count = checkedVerses[verse] ?? 0;
                          if (count < ReadingSessionManager.maximumReadCount) {
                            manager.markVerseAsRead(
                              widget.bookId,
                              widget.chapter,
                              verse,
                            );
                          } else {
                            manager.resetVerseProgress(
                              widget.bookId,
                              widget.chapter,
                              verse,
                            );
                          }
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
                          final locale = Localizations.localeOf(context);
                          return manager.getPopupTextForId(
                            locale,
                            wordId,
                            (locale) => _handleMissingResources(locale),
                          );
                        },
                        onWordLongPress: _showWordDetails,
                        highlightedVerse: verseToHighlight,
                        highlightColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.25),
                      ),
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

  Future<void> _handleMissingResources(Locale locale) async {
    // Use the shared helper logic
    final success = await ResourceUIHelper.ensureResources(context, locale);

    if (!success && mounted) {
      // If they clicked "Cancel" or download failed,
      // tell the manager to stop trying to load localized glosses
      // for this session so they aren't prompted on every single tap.
      manager.setLanguageToEnglish(locale);
    } else if (success && mounted) {
      // Refresh the UI so the words show the newly downloaded glosses
      setState(() {});
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
