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
    geometry: ChapterGeometry(spans: spans),
  );
}

VerseSpan _span(int verse, double start, double end) =>
    VerseSpan(verse: verse, start: start, end: end);

void main() {
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
            2: _span(2, 10, 10),
            3: _span(3, 10, 30),
            4: _span(4, 30, 50),
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

    test('interpolation expands into half the adjacent gap', () {
      // Verse 4 is followed by a 10px gap before verse 6, so its interval
      // expands from [130, 150] to [130, 155].
      final position = SyncPosition(
        Anchor(_ref(4), AnchorEnd.start),
        Anchor(_ref(4), AnchorEnd.end),
        0.5,
      );
      expect(layout.resolvePosition(position), 142.5);
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
          1: _span(1, 0, 60),
          3: _span(3, 60, 60),
          4: _span(4, 60, 140),
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

  group('gap absorption (half-gap expansion)', () {
    // Follower layout: verse 1 [0,10], gap [10,20], verse 2 [20,30].
    SyncLayout gappedLayout() => SyncLayout([
      _snapshot(
        chapter: 1,
        top: 0,
        height: 30,
        spans: {1: _span(1, 0, 10), 2: _span(2, 20, 30)},
      ),
    ]);

    double resolveVerse(SyncLayout layout, int verse, double t) =>
        layout.resolvePosition(
          SyncPosition(
            Anchor(_ref(verse), AnchorEnd.start),
            Anchor(_ref(verse), AnchorEnd.end),
            t,
          ),
        )!;

    test('a follower-only gap is traversed across the verse boundary', () {
      final layout = gappedLayout();

      // Verse 1 expands into the top half of the gap; verse 2 starts from the
      // gap's midpoint. t=1 of verse 1 and t=0 of verse 2 meet at one pixel
      // instead of jumping over the gap.
      expect(resolveVerse(layout, 1, 0), 0);
      expect(resolveVerse(layout, 1, 0.5), 7.5);
      expect(resolveVerse(layout, 1, 1), 15);
      expect(resolveVerse(layout, 2, 0), 15);
      expect(resolveVerse(layout, 2, 0.5), 22.5);
      expect(resolveVerse(layout, 2, 1), 30);
    });

    test('a leader gap resolves to the gap midpoint band', () {
      final layout = gappedLayout();

      double resolveGap(double t) => layout.resolvePosition(
        SyncPosition(
          Anchor(_ref(1), AnchorEnd.end),
          Anchor(_ref(2), AnchorEnd.start),
          t,
        ),
      )!;

      // The band between the two half-gaps is degenerate for a single gap:
      // the follower holds at the midpoint while the leader crosses its own
      // gap, then hands off continuously.
      expect(resolveGap(0), 15);
      expect(resolveGap(0.5), 15);
      expect(resolveGap(1), 15);
    });

    test('missing verses park at the expanded gap midpoint', () {
      // Verse 2 is missing here: the gap [10,20] sits between verses 1 and 3.
      final layout = SyncLayout([
        _snapshot(
          chapter: 1,
          top: 0,
          height: 30,
          spans: {1: _span(1, 0, 10), 3: _span(3, 20, 30)},
        ),
      ]);

      double resolve(int verse, double t) => resolveVerse(layout, verse, t);

      expect(resolve(1, 1), 15);
      expect(resolve(2, 0), 15);
      expect(resolve(2, 1), 15);
      expect(resolve(3, 0), 15);
    });

    test('scrolling a gapped follower is monotonic', () {
      // Leader: 10 verses tiling 0..100 with no gaps. Follower: gaps between
      // every verse pair plus a missing verse.
      final leader = SyncLayout([
        _snapshot(
          chapter: 1,
          top: 0,
          height: 100,
          spans: {
            for (var verse = 1; verse <= 10; verse++)
              verse: _span(verse, (verse - 1) * 10.0, verse * 10.0),
          },
        ),
      ]);
      final follower = SyncLayout([
        _snapshot(
          chapter: 1,
          top: 0,
          height: 100,
          spans: {
            1: _span(1, 0, 8),
            2: _span(2, 12, 20),
            4: _span(4, 24, 32),
            5: _span(5, 36, 44),
            6: _span(6, 48, 56),
            7: _span(7, 60, 68),
            8: _span(8, 72, 80),
            9: _span(9, 84, 92),
            10: _span(10, 96, 100),
          },
        ),
      ]);

      var previous = double.negativeInfinity;
      for (var y = 0.0; y <= 100; y += 1) {
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
  });

  group('buildGeometry (heading absorption)', () {
    test('a chapter title is attributed to the first verse', () {
      final geometry = buildGeometry(
        spans: {1: _span(1, 40, 50), 2: _span(2, 50, 60)},
        headings: [const HeadingRect(top: 10, bottom: 30)],
      );

      // The span starts at the title's top; the space below the title is
      // interior span content, and no gap opens between verses 1 and 2.
      // Everything above the title's top stays outside any span.
      expect(geometry.spans[1]!.start, 10);
      expect(geometry.spans[1]!.end, 50);
      expect(geometry.spans[2]!.start, 50);
      expect(geometry.spans[2]!.end, 60);
    });

    test('a section heading between verses joins the following verse', () {
      final geometry = buildGeometry(
        spans: {1: _span(1, 0, 10), 2: _span(2, 40, 50)},
        headings: [const HeadingRect(top: 20, bottom: 30)],
      );

      // Verse 1 is untouched; verse 2 absorbs the heading, so the only open
      // region is the blank between verse 1's end and the heading's top.
      expect(geometry.spans[1]!.start, 0);
      expect(geometry.spans[1]!.end, 10);
      expect(geometry.spans[2]!.start, 20);
      expect(geometry.spans[2]!.end, 50);
    });

    test('stacked headings attribute to the same verse, topmost wins', () {
      final geometry = buildGeometry(
        spans: {1: _span(1, 40, 50)},
        headings: const [
          HeadingRect(top: 25, bottom: 30),
          HeadingRect(top: 10, bottom: 20),
        ],
      );

      expect(geometry.spans[1]!.start, 10);
      expect(geometry.spans[1]!.end, 50);
    });

    test('a trailing heading with no following verse stays unattributed', () {
      final geometry = buildGeometry(
        spans: {1: _span(1, 0, 10)},
        headings: [const HeadingRect(top: 40, bottom: 50)],
      );

      // The heading is attributed to no verse: verse 1 keeps its span and
      // nothing covers the heading's range.
      expect(geometry.spans, hasLength(1));
      expect(geometry.spans[1]!.start, 0);
      expect(geometry.spans[1]!.end, 10);
    });

    test('no headings leaves spans untouched', () {
      final spans = {1: _span(1, 0, 10), 2: _span(2, 20, 30)};
      final geometry = buildGeometry(spans: spans);

      expect(geometry.spans, spans);
    });
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

      controller.updatePosition('b', position, displayReference: null);
      expect(controller.position, isNull);

      controller.updatePosition('a', position, displayReference: null);
      expect(controller.position, position);
    });

    test('exposes the leader display reference and no chapter progress', () {
      final controller = ScrollSyncController();
      final position = SyncPosition(
        Anchor(_ref(4), AnchorEnd.start),
        Anchor(_ref(4), AnchorEnd.end),
        0,
      );

      controller.updatePosition('a', position, displayReference: _ref(4));

      expect(controller.displayReference, _ref(4));
    });
  });
}
