import 'package:gbt/services/logging/log.dart';

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:scripture/scripture.dart';
import 'package:scripture/scripture_core.dart' as core;
import 'package:gbt/common/book_name.dart';
import 'package:gbt/services/resources/resource.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/common/resource_language_text_direction.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';
import 'package:gbt/ui/home/panel_area/common/verse_sync_layout.dart';
import 'bible_chapter_manager.dart';

class BibleChapter extends StatefulWidget {
  const BibleChapter({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.verseLayout,
    this.fontSize = 20.0,
    this.settingsVersion = 0,
    this.onResourceUnavailable,
  });

  final int bookId;
  final int chapter;
  final double fontSize;
  final VerseLayout verseLayout;
  final int settingsVersion;
  final VoidCallback? onResourceUnavailable;

  @override
  State<BibleChapter> createState() => _BibleChapterState();
}

class _BibleChapterState extends State<BibleChapter> {
  final manager = BibleChapterManager();

  // Keyed so the chapter title can be measured and attributed to verse 1.
  final GlobalKey _titleKey = GlobalKey();

  ChapterGeometry? _geometry;
  List<UsfmLine> _verseLines = const [];

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
      _publishGeometry(null);
      _loadChapterData();
    } else if (widget.settingsVersion != oldWidget.settingsVersion &&
        manager.bibleChanged) {
      _publishGeometry(null);
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
    final success = await ResourceUIHelper().ensureResource(
      context,
      ResourceType.bible,
      bibleId,
    );

    if (!mounted) return;

    if (success) {
      // Retry the chapter load now that the bible is downloaded.
      _loadChapterData();
    } else {
      // The user declined the download, or it failed / was cancelled.
      // Close the panel instead of leaving it stuck in a loading state.
      widget.onResourceUnavailable?.call();
    }
  }

  void _publishGeometry(ChapterGeometry? geometry) {
    _geometry = geometry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dispatchGeometryChanged();
    });
  }

  void _dispatchGeometryChanged() {
    ChapterGeometryChangedNotification(
      bookId: widget.bookId,
      chapter: widget.chapter,
      geometry: _geometry,
    ).dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<UsfmLine>>(
      valueListenable: manager.textNotifier,
      builder: (context, verseLines, child) {
        _verseLines = verseLines;

        if (verseLines.isEmpty) {
          _publishGeometry(null);
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

        _scheduleGeometryMeasurement();

        return NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            _scheduleGeometryMeasurement();
            return false;
          },
          child: SizeChangedLayoutNotifier(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      key: _titleKey,
                      '${bookNameForId(context, widget.bookId)} ${widget.chapter}',
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: manager.textDirection.toTextDirection,
                    child: verses,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleGeometryMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureGeometry();
    });
  }

  void _measureGeometry() {
    final chapterBox = context.findRenderObject();
    if (chapterBox is! RenderBox || !chapterBox.hasSize) return;

    final passages = <RenderPassage>[];
    final seenPassages = Set<RenderPassage>.identity();

    void visitElement(Element element) {
      final renderObject = element.renderObject;
      if (renderObject is RenderPassage && seenPassages.add(renderObject)) {
        passages.add(renderObject);
      }
      element.visitChildren(visitElement);
    }

    context.visitChildElements(visitElement);
    if (passages.isEmpty) return;

    final sections = _measurementSections(_verseLines);
    final spans = <int, VerseSpan>{};

    for (var i = 0; i < passages.length; i++) {
      final passage = passages[i];
      if (!passage.attached) continue;

      final passageTop = passage
          .localToGlobal(Offset.zero, ancestor: chapterBox)
          .dy;

      final renderParagraphs = <RenderParagraph>[];
      RenderBox? child = passage.firstChild;
      while (child != null) {
        if (child is RenderParagraph) renderParagraphs.add(child);
        child = (child.parentData as PassageParentData).nextSibling;
      }

      final expected = i < sections.length
          ? _expectedParagraphs(sections[i])
          : const <_ExpectedParagraph>[];
      final aligned = expected.length == renderParagraphs.length;

      for (var j = 0; j < renderParagraphs.length; j++) {
        final paragraph = renderParagraphs[j];
        final parentData = paragraph.parentData as PassageParentData;
        final top = passageTop + parentData.offset.dy;
        final bottom = top + paragraph.size.height;
        final expectedVerses = aligned && j < expected.length
            ? expected[j].verses
            : const <int>[];

        _addParagraphSpans(
          spans: spans,
          paragraph: paragraph,
          chapterBox: chapterBox,
          top: top,
          bottom: bottom,
          expectedVerses: expectedVerses,
        );
      }
    }

    if (spans.isEmpty) {
      _publishGeometry(null);
      return;
    }

    final headings = <HeadingRect>[];
    final titleBox = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (titleBox != null && titleBox.attached && titleBox.hasSize) {
      final top = titleBox.localToGlobal(Offset.zero, ancestor: chapterBox).dy;
      headings.add(HeadingRect(top: top, bottom: top + titleBox.size.height));
    }

    _geometry = buildGeometry(
      spans: spans,
      headings: headings,
      height: chapterBox.size.height,
    );

    _dispatchGeometryChanged();
  }

  void _addParagraphSpans({
    required Map<int, VerseSpan> spans,
    required RenderParagraph paragraph,
    required RenderBox chapterBox,
    required double top,
    required double bottom,
    required List<int> expectedVerses,
  }) {
    final measured = <({int verse, double y})>[];

    void visitRender(RenderObject renderObject) {
      if (renderObject is RenderVerseNumber) {
        final verse = _parseVerseNumber(renderObject.number);
        if (verse != null) {
          final y = renderObject
              .localToGlobal(Offset.zero, ancestor: chapterBox)
              .dy;
          measured.add((verse: verse, y: y));
        }
      }
      renderObject.visitChildren(visitRender);
    }

    paragraph.visitChildren(visitRender);
    measured.sort((a, b) => a.y.compareTo(b.y));

    final seen = <int>{};
    final unique = [
      for (final item in measured)
        if (seen.add(item.verse)) item,
    ];

    final height = bottom - top;

    final expected = <int>[];
    final expectedSeen = <int>{};
    for (final verse in expectedVerses) {
      if (expectedSeen.add(verse)) expected.add(verse);
    }

    final needsVirtual = expected.isNotEmpty && unique.length < expected.length;

    if (needsVirtual) {
      final count = expected.length;
      for (var i = 0; i < count; i++) {
        final verse = expected[i];
        final start = top + height * i / count;
        final end = top + height * (i + 1) / count;
        spans[verse] = VerseSpan(verse: verse, start: start, end: end);
      }
      return;
    }

    if (unique.isEmpty) {
      // A paragraph without a verse number continues the previous verse (for
      // example a poetry line belonging to the same verse).
      if (spans.isNotEmpty && height > 0.01) {
        final lastVerse = spans.keys.reduce(math.max);
        final previous = spans[lastVerse]!;
        spans[lastVerse] = VerseSpan(
          verse: lastVerse,
          start: previous.start,
          end: math.max(previous.end, bottom),
        );
      }
      return;
    }

    for (var i = 0; i < unique.length; i++) {
      final item = unique[i];
      final start = item.y.clamp(top, bottom);
      final end = i + 1 < unique.length
          ? unique[i + 1].y.clamp(top, bottom)
          : bottom;

      spans[item.verse] = VerseSpan(
        verse: item.verse,
        start: start,
        end: math.max(start, end),
      );
    }
  }

  List<List<UsfmLine>> _measurementSections(List<UsfmLine> verseLines) {
    if (widget.verseLayout != VerseLayout.versePerLine) {
      return [verseLines];
    }

    final sections = <List<UsfmLine>>[];
    var current = <UsfmLine>[];
    int? verseNumber;

    for (final line in verseLines) {
      if (verseNumber == null || verseNumber == line.verse) {
        current.add(line);
      } else {
        sections.add(current);
        current = [line];
      }
      verseNumber = line.verse;
    }

    if (current.isNotEmpty) sections.add(current);
    return sections;
  }

  List<_ExpectedParagraph> _expectedParagraphs(List<UsfmLine> verseLines) {
    final passage = UsfmParser.parse(verseLines, showHeadings: false);
    final paragraphs = <_ExpectedParagraph>[];

    for (final paragraph in passage.paragraphs) {
      if (paragraph.format == core.ParagraphFormat.b) continue;

      final verses = <int>[];
      for (final element in paragraph.content) {
        if (element is core.VerseNumber) {
          final verse = _parseVerseNumber(element.number);
          if (verse != null) verses.add(verse);
        }
      }
      paragraphs.add(_ExpectedParagraph(verses));
    }

    return paragraphs;
  }

  int? _parseVerseNumber(String number) {
    final match = RegExp(r'\d+').firstMatch(number);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  Widget buildUsfm(List<UsfmLine> verseLines) {
    return UsfmWidget(
      verseLines: verseLines,
      selectionController: ScriptureSelectionController(),
      onFootnoteTapped: (footnote) {
        _showFootnoteDialog(footnote, manager.textDirection.toTextDirection);
      },
      onWordTapped: (id) => debug("Tapped word $id"),
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

  Future<void> _showFootnoteDialog(
    String footnote,
    TextDirection textDirection,
  ) async {
    return await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Text(
                footnote,
                textDirection: textDirection,
                style: TextStyle(fontSize: widget.fontSize),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExpectedParagraph {
  const _ExpectedParagraph(this.verses);

  final List<int> verses;
}
