import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studyapp/common/book_name.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/chapter_manager.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/text.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/panel_manager.dart';
import 'package:studyapp/ui/home/home.dart';
import 'package:studyapp/ui/home/word_details_dialog/word_details_dialog.dart';

/// Manages fetching data and alerts for a single chapter.
class HebrewGreekChapter extends StatefulWidget {
  const HebrewGreekChapter({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.fontSize,
    required this.manager,
  });

  final int bookId;
  final int chapter;
  final double fontSize;
  final HebrewGreekPanelManager manager;

  @override
  State<HebrewGreekChapter> createState() => _HebrewGreekChapterState();
}

class _HebrewGreekChapterState extends State<HebrewGreekChapter> {
  final manager = HebrewGreekChapterManager();

  @override
  void initState() {
    super.initState();
    manager.loadChapterData(widget.bookId, widget.chapter);
  }

  @override
  void didUpdateWidget(covariant HebrewGreekChapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If Flutter reuses this widget for a new chapter, fetch the new chapter's data.
    if (widget.bookId != oldWidget.bookId ||
        widget.chapter != oldWidget.chapter) {
      manager.loadChapterData(widget.bookId, widget.chapter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<HebrewGreekWord>>(
      valueListenable: manager.textNotifier,
      builder: (context, words, child) {
        if (words.isEmpty) {
          return const SizedBox();
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
                words: words,
                textDirection: manager.isRtl(widget.bookId)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                textStyle: TextStyle(fontSize: widget.fontSize),
                verseNumberStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: widget.fontSize * 0.7,
                ),
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
                    _showDownloadDialog,
                  );
                },
                onWordLongPress: _showWordDetails,
              ),
            ],
          ),
        );
      },
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
