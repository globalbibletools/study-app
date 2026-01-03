import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:scripture/scripture.dart';
import 'package:studyapp/common/book_name.dart';
import 'bible_chapter_manager.dart';

class BibleChapter extends StatefulWidget {
  const BibleChapter({
    super.key,
    required this.bookId,
    required this.chapter,
    this.fontSize = 20.0,
  });

  final int bookId;
  final int chapter;
  final double fontSize;

  @override
  State<BibleChapter> createState() => _BibleChapterState();
}

class _BibleChapterState extends State<BibleChapter> {
  final manager = BibleChapterManager();

  @override
  void initState() {
    super.initState();
    manager.loadChapterData(widget.bookId, widget.chapter);
  }

  @override
  void didUpdateWidget(covariant BibleChapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookId != oldWidget.bookId ||
        widget.chapter != oldWidget.chapter) {
      manager.loadChapterData(widget.bookId, widget.chapter);
    }
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<UsfmLine>>(
      valueListenable: manager.textNotifier,
      builder: (context, verseLines, child) {
        if (verseLines.isEmpty) {
          // You might want a loading indicator here
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
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
              UsfmWidget(
                verseLines: verseLines,
                selectionController: ScriptureSelectionController(),
                onFootnoteTapped: (footnote) {},
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
              ),
            ],
          ),
        );
      },
    );
  }
}
