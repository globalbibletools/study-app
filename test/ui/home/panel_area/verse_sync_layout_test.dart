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

    test('spans are made contiguous by gap absorption', () {
      final blocks = layout.blocks;
      expect(blocks, hasLength(5));
      expect(blocks.every((block) => block.isVerse), isTrue);

      expect(resolve(4, AnchorEnd.end), 160);
      expect(resolve(6, AnchorEnd.end), 200);
    });

    test('present zero-height spans resolve both edges to one point', () {
      expect(resolve(2, AnchorEnd.start), 110);
      expect(resolve(2, AnchorEnd.end), 110);
    });

    test('adjacent verse boundaries share exactly the same pixel', () {
      expect(resolve(1, AnchorEnd.end), resolve(2, AnchorEnd.start));
      expect(resolve(2, AnchorEnd.end), resolve(3, AnchorEnd.start));
      expect(resolve(3, AnchorEnd.end), resolve(4, AnchorEnd.start));
      expect(resolve(4, AnchorEnd.end), resolve(6, AnchorEnd.start));
    });

    test('missing verses park at the shared boundary', () {
      expect(resolve(5, AnchorEnd.start), 160);
      expect(resolve(5, AnchorEnd.end), 160);
    });

    test('null anchors resolve to the loaded extremes', () {
      expect(layout.resolveAnchor(const Anchor.top()), 100);
      expect(layout.resolveAnchor(const Anchor.bottom()), 200);
    });

    test('leader reports the verse interval containing the viewport top', () {
      final info = layout.leaderAt(125, 40)!;
      expect(info.position.from, Anchor(_ref(3), AnchorEnd.start));
      expect(info.position.to, Anchor(_ref(3), AnchorEnd.end));
      expect(info.position.t, closeTo(0.75, 0.0001));
      expect(info.displayReference, _ref(4));
    });

    test('unloaded chapters do not resolve positions', () {
      final withUnloaded = SyncLayout([
        _snapshot(
          chapter: 1,
          top: 0,
          height: 100,
          spans: {1: _span(1, 0, 100)},
        ),
        ChapterLayoutSnapshot(
          reference: const Reference(bookId: 1, chapter: 2, verse: 1),
          top: 100,
          height: 100,
          geometry: null,
        ),
        _snapshot(
          chapter: 3,
          top: 200,
          height: 100,
          spans: {1: _span(1, 0, 100)},
        ),
      ]);

      expect(
        withUnloaded.resolveAnchor(
          Anchor(_ref(1, chapter: 2), AnchorEnd.start),
        ),
        isNull,
      );
      expect(
        withUnloaded.resolvePosition(
          SyncPosition(
            Anchor(_ref(1, chapter: 2), AnchorEnd.start),
            Anchor(_ref(1, chapter: 2), AnchorEnd.end),
            0.5,
          ),
        ),
        isNull,
      );

      expect(withUnloaded.leaderAt(150, 20), isNull);
    });
  });

  test('chapters tile without cross-chapter gaps', () {
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

    expect(layout.blocks, hasLength(3));
    expect(layout.blocks.every((block) => block.isVerse), isTrue);

    expect(
      layout.resolveAnchor(Anchor(_ref(2, chapter: 1), AnchorEnd.end)),
      100,
    );
    expect(
      layout.resolveAnchor(Anchor(_ref(1, chapter: 2), AnchorEnd.start)),
      100,
    );
  });

  test('bottom trailing extent belongs to the last verse', () {
    final layout = SyncLayout([
      _snapshot(chapter: 1, top: 0, height: 100, spans: {1: _span(1, 0, 100)}),
    ], trailingExtent: 300);

    expect(layout.blocks.single.verse, _ref(1));
    expect(layout.resolveAnchor(Anchor(_ref(1), AnchorEnd.end)), 400);
    expect(layout.resolveAnchor(const Anchor.bottom()), 400);
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

  group('buildGeometry (heading absorption and contiguity)', () {
    test('a chapter title is attributed to the first verse', () {
      final geometry = buildGeometry(
        spans: {1: _span(1, 40, 50), 2: _span(2, 50, 60)},
        headings: [const HeadingRect(top: 10, bottom: 30)],
        height: 60,
      );

      expect(geometry.spans[1]!.start, 0);
      expect(geometry.spans[1]!.end, 50);
      expect(geometry.spans[2]!.start, 50);
      expect(geometry.spans[2]!.end, 60);
    });

    test('a section heading joins the following verse', () {
      final geometry = buildGeometry(
        spans: {1: _span(1, 0, 10), 2: _span(2, 40, 50)},
        headings: [const HeadingRect(top: 20, bottom: 30)],
        height: 50,
      );

      expect(geometry.spans[1]!.start, 0);
      expect(geometry.spans[1]!.end, 20);
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
        height: 50,
      );

      expect(geometry.spans[1]!.start, 0);
      expect(geometry.spans[1]!.end, 50);
    });

    test('a trailing heading is absorbed by the last verse', () {
      final geometry = buildGeometry(
        spans: {1: _span(1, 0, 10)},
        headings: [const HeadingRect(top: 40, bottom: 50)],
        height: 50,
      );

      expect(geometry.spans[1]!.start, 0);
      expect(geometry.spans[1]!.end, 50);
    });

    test('no headings still fills gaps below each verse', () {
      final geometry = buildGeometry(
        spans: {1: _span(1, 0, 10), 2: _span(2, 20, 30)},
        height: 30,
      );

      expect(geometry.spans[1]!.start, 0);
      expect(geometry.spans[1]!.end, 20);
      expect(geometry.spans[2]!.start, 20);
      expect(geometry.spans[2]!.end, 30);
    });

    test('missing verses are absent and add no size', () {
      final geometry = buildGeometry(
        spans: {1: _span(1, 0, 10), 3: _span(3, 20, 30)},
        height: 30,
      );

      expect(geometry.spans.keys, [1, 3]);
      expect(geometry.spans[1]!.end, 20);
      expect(geometry.spans[3]!.start, 20);
    });

    test('normalized spans tile the chapter exactly', () {
      final geometry = buildGeometry(
        spans: {1: _span(1, 10, 20), 2: _span(2, 20, 20), 4: _span(4, 35, 40)},
        height: 50,
      );

      final spans = geometry.spans.values.toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      expect(spans.first.start, 0);
      expect(spans.last.end, 50);
      for (var i = 1; i < spans.length; i++) {
        expect(spans[i].start, spans[i - 1].end);
      }
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
