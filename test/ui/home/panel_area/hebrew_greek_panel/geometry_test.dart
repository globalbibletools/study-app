import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/ui/home/panel_area/hebrew_greek_panel/geometry.dart';

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
        verses: [1, 2, 3, 4],
      );

      expect(geometry.spans[1]!.start, 0);
      expect(geometry.spans[1]!.end, 10);

      // Verse 2 starts on the same line as verse 3, so it owns no lines.
      expect(geometry.spans[2]!.start, 10);
      expect(geometry.spans[2]!.end, 10);

      // Verse 3 owns line 1 and its continuation line.
      expect(geometry.spans[3]!.start, 10);
      expect(geometry.spans[3]!.end, 30);

      // A wrapping verse whose last line is shared with the next verse is
      // clipped at that line's top.
      expect(geometry.spans[4]!.start, 30);
      expect(geometry.spans[4]!.end, 50);
    });

    test('verses with no rendered words park at the end of the last owner', () {
      final geometry = geometryFromLines(
        [
          const LineLayout(top: 0, bottom: 10, startingVerses: [1]),
          const LineLayout(top: 10, bottom: 20, startingVerses: [2]),
          const LineLayout(top: 20, bottom: 30, startingVerses: []),
        ],
        verses: [1, 2, 3, 4],
      );

      // Verse 2 owns its own line and the continuation line.
      expect(geometry.spans[2]!.end, 30);

      // Verses 3 and 4 have no rendered words: they park, zero-height, at
      // the end of the last owned verse, forming one handoff point.
      expect(geometry.spans[3]!.start, 30);
      expect(geometry.spans[3]!.end, 30);
      expect(geometry.spans[4]!.start, 30);
      expect(geometry.spans[4]!.end, 30);
    });

    test('missing leading verses park at the top', () {
      final geometry = geometryFromLines(
        [
          const LineLayout(top: 10, bottom: 20, startingVerses: [2]),
        ],
        verses: [1, 2],
      );

      expect(geometry.spans[1]!.start, 0);
      expect(geometry.spans[1]!.end, 0);
      expect(geometry.spans[2]!.start, 10);
      expect(geometry.spans[2]!.end, 20);
    });

    test('verses absent from the renderer are omitted', () {
      final geometry = geometryFromLines(
        [
          const LineLayout(top: 0, bottom: 10, startingVerses: [1]),
          const LineLayout(top: 10, bottom: 20, startingVerses: [2]),
          const LineLayout(top: 20, bottom: 30, startingVerses: [4]),
        ],
        verses: [1, 2, 4],
      );

      expect(geometry.spans.keys, [1, 2, 4]);
      expect(geometry.spans.containsKey(3), isFalse);
      expect(geometry.spans[4]!.start, 20);
      expect(geometry.spans[4]!.end, 30);
    });

    test('spans are disjoint and ordered', () {
      final geometry = geometryFromLines(
        [
          const LineLayout(top: 0, bottom: 10, startingVerses: [1]),
          const LineLayout(top: 10, bottom: 20, startingVerses: [2]),
          const LineLayout(top: 20, bottom: 30, startingVerses: []),
        ],
        verses: [1, 2, 3],
      );

      final spans = geometry.spans.values.toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      for (var i = 0; i < spans.length; i++) {
        expect(spans[i].end, greaterThanOrEqualTo(spans[i].start));
        if (i > 0) {
          expect(spans[i].start, greaterThanOrEqualTo(spans[i - 1].start));
        }
      }
    });
  });
}
