import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:scripture/scripture.dart';
import 'package:gbt/common/book_name.dart';
import 'package:gbt/services/resources/resource.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';
import 'bible_chapter_manager.dart';

class BibleChapter extends StatefulWidget {
  const BibleChapter({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.verseLayout,
    this.fontSize = 20.0,
  });

  final int bookId;
  final int chapter;
  final double fontSize;
  final VerseLayout verseLayout;

  @override
  State<BibleChapter> createState() => _BibleChapterState();
}

class _BibleChapterState extends State<BibleChapter> {
  final manager = BibleChapterManager();

  @override
  void initState() {
    super.initState();
    _loadChapterData();
  }

  @override
  void didUpdateWidget(covariant BibleChapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookId != oldWidget.bookId ||
        widget.chapter != oldWidget.chapter) {
      _loadChapterData();
    }
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  void _loadChapterData() {
    manager.loadChapterData(
      widget.bookId,
      widget.chapter,
      onDatabaseMissing: _handleMissingBible,
    );
  }

  Future<void> _handleMissingBible(String bibleId) async {
    final success = await ResourceUIHelper.ensureResource(
      context,
      ResourceType.bible,
      bibleId,
    );

    if (success && mounted) {
      // Retry the chapter load now that the bible is downloaded.
      _loadChapterData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<UsfmLine>>(
      valueListenable: manager.textNotifier,
      builder: (context, verseLines, child) {
        if (verseLines.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final Widget verses;

        if (widget.verseLayout == VerseLayout.versePerLine) {
          List<Widget> listVerses = [];
          List<UsfmLine> lines = [];

          int? verseNumber;

          for (UsfmLine line in verseLines) {
            if (verseNumber == null || verseNumber == line.verse) {
              lines.add(line);
            } else {
              listVerses.add(buildUsfm(lines));
              lines = [];
              lines.add(line);
            }
            verseNumber = line.verse;
          }

          listVerses.add(buildUsfm(lines));

          verses = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: listVerses,
          );
        } else {
          verses = buildUsfm(verseLines);
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '${bookNameForId(context, widget.bookId)} ${widget.chapter}',
                  style: const TextStyle(fontSize: 30),
                ),
              ),
              const SizedBox(height: 10),
              verses,
            ],
          ),
        );
      },
    );
  }

  Widget buildUsfm(List<UsfmLine> verseLines) {
    return UsfmWidget(
      verseLines: verseLines,
      selectionController: ScriptureSelectionController(),
      onFootnoteTapped: (footnote) {
        _showFootnoteDialog(footnote);
      },
      onWordTapped: (id) => log("Tapped word $id"),
      onSelectionRequested: (wordId) {},
      showHeadings: false,
      styleBuilder: (format) {
        final baseStyle = UsfmParagraphStyle.usfmDefaults(
          format: format,
          baseStyle: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(fontSize: widget.fontSize),
        );
        return baseStyle.copyWith(
          verseNumberStyle: baseStyle.textStyle.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }

  Future<void> _showFootnoteDialog(String footnote) async {
    return await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Text(
                footnote,
                style: TextStyle(fontSize: widget.fontSize),
              ),
            ),
          ),
        );
      },
    );
  }
}
