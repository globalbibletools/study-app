import 'package:flutter/material.dart';
import 'package:scripture/scripture.dart';
import 'package:studyapp/common/book_name.dart';
import 'bible_chapter_manager.dart';

class BibleChapter extends StatefulWidget {
  const BibleChapter({super.key, required this.bookId, required this.chapter});

  final int bookId;
  final int chapter;

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
              // Optional: Render a header for the chapter
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  '${bookNameForId(context, widget.bookId)} ${widget.chapter}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              UsfmWidget(
                verseLines: verseLines,
                selectionController: ScriptureSelectionController(),
                onFootnoteTapped: (footnote) {},
                onWordTapped: (id) => print("Tapped word $id"),
                onSelectionRequested: (wordId) {},
                styleBuilder: (format) {
                  return UsfmParagraphStyle.usfmDefaults(
                    format: format,
                    baseStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 20, // Or inject font size from settings
                    ),
                  );
                },
              ),
              // Add a divider to visually separate chapters
              const Divider(height: 40, thickness: 2),
            ],
          ),
        );
      },
    );
  }
}
