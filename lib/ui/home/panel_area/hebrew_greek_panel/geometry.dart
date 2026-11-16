import 'package:flutter/foundation.dart';

import 'package:gbt/ui/home/panel_area/common/verse_sync_layout.dart';

/// A single laid-out line of the Hebrew/Greek text renderer.
@immutable
class LineLayout {
  const LineLayout({
    required this.top,
    required this.bottom,
    required this.startingVerses,
  });

  final double top;
  final double bottom;

  /// Verses whose number/first word starts on this line, in document order.
  final List<int> startingVerses;

  double get height => bottom - top;
}

/// Derives verse spans from line ownership.
///
/// Each line is owned by the last verse that starts on it. Lines where no
/// verse starts extend the previous owner. A verse that owns no lines gets a
/// zero-height span at the top of the line where it starts, and a verse with
/// no rendered content parks at the end of the last verse that owned lines.
ChapterGeometry geometryFromLines(
  List<LineLayout> lines, {
  required int verseCount,
}) {
  final spans = <int, VerseSpan>{};
  var lineIndex = 0;
  var lastEnd = 0.0;

  for (var verse = 1; verse <= verseCount; verse++) {
    final List<int> starts = lineIndex < lines.length
        ? lines[lineIndex].startingVerses
        : const <int>[];
    final owner = starts.isEmpty ? null : starts.last;

    if (owner == verse) {
      // The verse owns this line and any continuation lines after it.
      final start = lines[lineIndex].top;
      var end = lines[lineIndex].bottom;
      lineIndex++;
      while (lineIndex < lines.length &&
          lines[lineIndex].startingVerses.isEmpty) {
        end = lines[lineIndex].bottom;
        lineIndex++;
      }
      spans[verse] = VerseSpan(verse: verse, start: start, end: end);
      lastEnd = end;
    } else if (starts.contains(verse)) {
      // The verse starts on a line owned by a later verse.
      final y = lines[lineIndex].top;
      spans[verse] = VerseSpan(verse: verse, start: y, end: y);
    } else {
      // No rendered content: park at the end of the last owned verse.
      spans[verse] = VerseSpan(verse: verse, start: lastEnd, end: lastEnd);
    }
  }

  return ChapterGeometry(spans: spans);
}
