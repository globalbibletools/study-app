import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/ui/home/common/scroll_sync_controller.dart';
import 'package:gbt/ui/home/panel_area/common/verse_sync_layout.dart';

Reference _ref(int verse, {int chapter = 1}) =>
    Reference(bookId: 1, chapter: chapter, verse: verse);

ChapterLayoutSnapshot _snapshot({
  required int chapter,
  required double top,
  required double height,
  required Map<int, VerseSpan> spans,
}) {
  return ChapterLayoutSnapshot(
    reference: Reference(bookId: 1, chapter: chapter, verse: 1),
    top: top,
    height: height,
    geometry: ChapterGeometry(
      spans: spans,
      gaps: deriveGapSpans(spans, height),
    ),
  );
}

VerseSpan _span(
  int verse,
  double start,
  double end, [
  SpanKind kind = SpanKind.exact,
]) => VerseSpan(verse: verse, start: start, end: end, kind: kind);

void main() {
  group('geometryFromLines (line ownership)', () {
    test('assigns lines to the last verse that starts on them', () {
      final geometry = geometryFromLines(
        [
          const LineLayout(top: 0, bottom: 10, startingVerses: [1]),
          const LineLayout(top: 10, bottom: 20, startingVerses: [2, 3]),
          const LineLayout(top: 20, bottom: 30, startingVerses: []),
          const LineLayout(top: 30, bottom: 40, startingVerses: [4]),
          const LineLayout(top: 40, bottom: 50, startingVerses: []),
        ],
        allVerses: const [1, 2, 3, 4],
      );

      expect(geometry.spans[1]!.start, 0);
      expect(geometry.spans[1]!.end, 10);
      expect(geometry.spans[1]!.kind, SpanKind.exact);

      // Verse 2 starts on the same line as verse 3, so it owns no lines.
      expect(geometry.spans[2]!.start, 10);
      expect(geometry.spans[2]!.end, 10);
      expect(geometry.spans[2]!.kind, SpanKind.zero);

      // Verse 3 owns line 1 and its continuation line.
      expect(geometry.spans[3]!.start, 10);
      expect(geometry.spans[3]!.end, 30);

      // A wrapping verse whose last line is shared with the next verse is
      // clipped at that line's top.
      expect(geometry.spans[4]!.start, 30);
      expect(geometry.spans[4]!.end, 50);
    });

    test('a verse with no starting line is zero-height at the end', () {
      final geometry = geometryFromLines(
        [
          const LineLayout(top: 0, bottom: 10, startingVerses: [1]),
          const LineLayout(top: 10, bottom: 20, startingVerses: []),
        ],
        allVerses: const [1, 2],
        height: 20,
      );

      expect(geometry.spans[2]!.start, 20);
      expect(geometry.spans[2]!.end, 20);
      expect(geometry.spans[2]!.kind, SpanKind.zero);
    });

    test('spans are disjoint, ordered, and gaps are non-negative', () {
      final geometry = geometryFromLines(
        [
          const LineLayout(top: 0, bottom: 10, startingVerses: [1]),
          const LineLayout(top: 10, bottom: 20, startingVerses: [2]),
          const LineLayout(top: 20, bottom: 30, startingVerses: []),
        ],
        allVerses: const [1, 2, 3],
      );

      final spans = geometry.spans.values.toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      for (var i = 0; i < spans.length; i++) {
        expect(spans[i].end, greaterThanOrEqualTo(spans[i].start));
        if (i > 0) {
          expect(spans[i].start, greaterThanOrEqualTo(spans[i - 1].start));
        }
      }
      for (final gap in geometry.gaps) {
        expect(gap.end, greaterThanOrEqualTo(gap.start));
      }
    });
  });

  group('SyncLayout anchor resolution', () {
    late SyncLayout layout;

    setUp(() {
      layout = SyncLayout([
        _snapshot(
          chapter: 1,
          top: 100,
          height: 100,
          spans: {
            1: _span(1, 0, 10),
            2: _span(2, 10, 10, SpanKind.zero),
            3: _span(3, 10, 30),
            4: _span(4, 30, 50, SpanKind.virtual),
            6: _span(6, 60, 80),
          },
        ),
      ]);
    });

    double? resolve(int verse, AnchorEnd end) =>
        layout.resolveAnchor(Anchor(_ref(verse), end));

    test('exact spans resolve to their measured edges', () {
      expect(resolve(1, AnchorEnd.start), 100);
      expect(resolve(1, AnchorEnd.end), 110);
      expect(resolve(3, AnchorEnd.start), 110);
      expect(resolve(3, AnchorEnd.end), 130);
    });

    test('zero-height spans resolve both edges to one point', () {
      expect(resolve(2, AnchorEnd.start), 110);
      expect(resolve(2, AnchorEnd.end), 110);
    });

    test('virtual spans resolve inside their even slice', () {
      expect(resolve(4, AnchorEnd.start), 130);
      expect(resolve(4, AnchorEnd.end), 150);
    });

    test('missing verses park at the end of the previous existing verse', () {
      expect(resolve(5, AnchorEnd.start), 150);
      expect(resolve(5, AnchorEnd.end), 150);
    });

    test('null anchors resolve to the scrollable extremes', () {
      expect(layout.resolveAnchor(const Anchor.top()), 100);
      expect(layout.resolveAnchor(const Anchor.bottom()), 200);
    });

    test('interpolation is linear between the resolved anchors', () {
      final position = SyncPosition(
        Anchor(_ref(4), AnchorEnd.start),
        Anchor(_ref(4), AnchorEnd.end),
        0.5,
      );
      expect(layout.resolvePosition(position), 140);
    });

    test('leader reports the verse interval containing the viewport top', () {
      final info = layout.leaderAt(125, 30)!;
      expect(info.position.from, Anchor(_ref(3), AnchorEnd.start));
      expect(info.position.to, Anchor(_ref(3), AnchorEnd.end));
      expect(info.position.t, closeTo(0.75, 0.0001));
      expect(info.displayReference, _ref(4));
    });

    test('gap leader reports cross to the following verse', () {
      final info = layout.leaderAt(155, 10)!;
      expect(info.position.from, Anchor(_ref(4), AnchorEnd.end));
      expect(info.position.to, Anchor(_ref(6), AnchorEnd.start));
      expect(info.position.t, closeTo(0.5, 0.0001));
    });
  });

  test('cross-chapter boundary gaps merge into one interval', () {
    final layout = SyncLayout([
      _snapshot(
        chapter: 1,
        top: 0,
        height: 100,
        spans: {1: _span(1, 0, 50), 2: _span(2, 50, 90)},
      ),
      _snapshot(
        chapter: 2,
        top: 100,
        height: 100,
        spans: {1: _span(1, 10, 50)},
      ),
    ]);

    final gap = layout.blocks.firstWhere((block) => block.isGap);
    expect(gap.start, 90);
    expect(gap.end, 110);
    expect(gap.from, Anchor(_ref(2, chapter: 1), AnchorEnd.end));
    expect(gap.to, Anchor(_ref(1, chapter: 2), AnchorEnd.start));

    // t = 1 of the previous unit and t = 0 of the gap meet at one pixel.
    expect(
      layout.resolveAnchor(Anchor(_ref(2, chapter: 1), AnchorEnd.end)),
      gap.start,
    );
    expect(
      layout.resolveAnchor(Anchor(_ref(1, chapter: 2), AnchorEnd.start)),
      gap.end,
    );
  });

  test('book extremes use null anchors', () {
    final layout = SyncLayout([
      _snapshot(chapter: 1, top: 0, height: 100, spans: {1: _span(1, 20, 80)}),
    ]);

    final topInfo = layout.leaderAt(0, 10)!;
    expect(topInfo.position.from, const Anchor.top());
    expect(topInfo.position.to, Anchor(_ref(1), AnchorEnd.start));

    final bottomInfo = layout.leaderAt(100, 10)!;
    expect(bottomInfo.position.to, const Anchor.bottom());
  });

  test('scrolling down is monotonic against coarse and missing layouts', () {
    ChapterLayoutSnapshot chapter({
      required double top,
      required Map<int, VerseSpan> spans,
      int chapterNumber = 1,
    }) {
      return _snapshot(
        chapter: chapterNumber,
        top: top,
        height: 200,
        spans: spans,
      );
    }

    final leader = SyncLayout([
      chapter(
        top: 0,
        spans: {
          for (var verse = 1; verse <= 10; verse++)
            verse: _span(verse, (verse - 1) * 20.0, verse * 20.0),
        },
      ),
    ]);

    // Coarse follower: a paragraph-sized virtual span plus a missing verse and
    // a zero-height verse.
    final follower = SyncLayout([
      chapter(
        top: 0,
        spans: {
          1: _span(1, 0, 60, SpanKind.virtual),
          3: _span(3, 60, 60, SpanKind.zero),
          4: _span(4, 60, 140, SpanKind.virtual),
          6: _span(6, 140, 200),
        },
      ),
    ]);

    var previous = double.negativeInfinity;
    for (var y = 0.0; y <= 200; y += 2) {
      final info = leader.leaderAt(y, 20)!;
      final resolved = follower.resolvePosition(info.position)!;
      expect(
        resolved,
        greaterThanOrEqualTo(previous - 0.0001),
        reason: 'follower moved up at y=$y',
      );
      previous = resolved;
    }
  });

  group('ScrollSyncController', () {
    test('ignores reports from a non-active source', () {
      final controller = ScrollSyncController();
      controller.setActiveSource('a');
      final position = SyncPosition(
        Anchor(_ref(1), AnchorEnd.start),
        Anchor(_ref(1), AnchorEnd.end),
        0,
      );

      controller.updatePosition('b', position);
      expect(controller.position, isNull);

      controller.updatePosition('a', position);
      expect(controller.position, position);
    });

    test('exposes the leader display verse and no chapter progress', () {
      final controller = ScrollSyncController();
      final position = SyncPosition(
        Anchor(_ref(4), AnchorEnd.start),
        Anchor(_ref(4), AnchorEnd.end),
        0,
      );

      controller.updatePosition(
        'a',
        position,
        displayVerse: 4,
        displayReference: _ref(4),
      );

      expect(controller.displayVerse, 4);
      expect(controller.displayReference, _ref(4));
    });
  });
}
