import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/ui/home/common/scroll_sync_controller.dart';

@immutable
class VerseSpan {
  const VerseSpan({
    required this.verse,
    required this.start,
    required this.end,
  });

  final int verse;
  final double start;
  final double end;

  double get height => end - start;

  @override
  String toString() => 'VerseSpan($verse, $start..$end)';
}

@immutable
class ChapterGeometry {
  const ChapterGeometry({required this.spans});

  final Map<int, VerseSpan> spans;

  int? get firstVerse =>
      spans.isEmpty ? null : spans.keys.reduce((a, b) => a < b ? a : b);

  int? get lastVerse =>
      spans.isEmpty ? null : spans.keys.reduce((a, b) => a > b ? a : b);

  ChapterGeometry translated(double dy) {
    if (dy == 0) return this;
    return ChapterGeometry(
      spans: {
        for (final entry in spans.entries)
          entry.key: VerseSpan(
            verse: entry.value.verse,
            start: entry.value.start + dy,
            end: entry.value.end + dy,
          ),
      },
    );
  }
}

mixin ChapterGeometryProvider {
  ChapterGeometry? get geometry;
}

class ChapterGeometryChangedNotification extends Notification {
  const ChapterGeometryChangedNotification();
}

@immutable
class ChapterLayoutSnapshot {
  const ChapterLayoutSnapshot({
    required this.reference,
    required this.top,
    required this.height,
    required this.geometry,
    this.firstVerse,
    this.lastVerse,
  });

  final Reference reference;
  int get bookId => reference.bookId;
  int get chapter => reference.chapter;
  final int? firstVerse;
  final int? lastVerse;

  final double top;
  final double height;

  final ChapterGeometry? geometry;
}

@immutable
class SyncLayoutBlock {
  const SyncLayoutBlock({
    required this.start,
    required this.end,
    required this.from,
    required this.to,
    this.verse,
  });

  final double start;
  final double end;

  final Anchor from;
  final Anchor to;

  final Reference? verse;

  bool get isVerse => verse != null;
  double get height => end - start;

  @override
  String toString() =>
      'SyncLayoutBlock($start..$end, ${verse ?? 'gap'}, $from -> $to)';
}

@immutable
class SyncLeaderInfo {
  const SyncLeaderInfo({
    required this.position,
    required this.displayReference,
  });

  final SyncPosition position;
  final Reference? displayReference;
}

const double _eps = 0.01;

@immutable
class HeadingRect {
  const HeadingRect({required this.top, required this.bottom});

  final double top;
  final double bottom;

  double get height => bottom - top;

  @override
  String toString() => 'HeadingRect($top..$bottom)';
}

ChapterGeometry buildGeometry({
  required Map<int, VerseSpan> spans,
  required double height,
  List<HeadingRect> headings = const [],
}) {
  if (spans.isEmpty) return const ChapterGeometry(spans: {});

  final ordered = spans.values.toList()
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.verse.compareTo(b.verse);
    });
  final sortedHeadings = headings.toList()
    ..sort((a, b) => a.bottom.compareTo(b.bottom));

  final boundedHeight = math.max(0.0, height);
  final result = <int, VerseSpan>{};
  var headingIndex = 0;
  var cut = 0.0;
  var previousStart = 0.0;
  int? previousVerse;

  for (var i = 0; i < ordered.length; i++) {
    final span = ordered[i];
    var start = span.start;

    while (headingIndex < sortedHeadings.length &&
        sortedHeadings[headingIndex].bottom - _eps <= span.start) {
      final heading = sortedHeadings[headingIndex++];
      if (heading.top < start - _eps) start = heading.top;
    }

    if (i > 0) {
      cut = math.max(cut, start.clamp(0.0, boundedHeight));
    }

    if (previousVerse != null) {
      result[previousVerse] = VerseSpan(
        verse: previousVerse,
        start: previousStart,
        end: cut,
      );
    }

    result[span.verse] = VerseSpan(verse: span.verse, start: cut, end: cut);
    previousVerse = span.verse;
    previousStart = cut;
  }

  if (previousVerse != null) {
    result[previousVerse] = VerseSpan(
      verse: previousVerse,
      start: previousStart,
      end: boundedHeight,
    );
  }

  return ChapterGeometry(spans: result);
}

class SyncLayout {
  SyncLayout(this.chapters, {double trailingExtent = 0}) {
    _build(trailingExtent);
  }

  final List<ChapterLayoutSnapshot> chapters;
  final List<SyncLayoutBlock> _blocks = [];
  final Map<int, ChapterLayoutSnapshot> _chaptersByKey = {};

  /// Blocks in document order, tiling the measured content.
  List<SyncLayoutBlock> get blocks => List.unmodifiable(_blocks);

  bool get isEmpty => _blocks.isEmpty;

  int _chapterKey(int bookId, int chapter) => bookId * 1000 + chapter;

  ChapterLayoutSnapshot? chapterFor(int bookId, int chapter) =>
      _chaptersByKey[_chapterKey(bookId, chapter)];

  void _build(double trailingExtent) {
    for (var i = 0; i < chapters.length; i++) {
      final snapshot = chapters[i];
      final geometry = snapshot.geometry;

      if (geometry == null || geometry.spans.isEmpty) continue;

      final isLast = i == chapters.length - 1;
      final height = snapshot.height + (isLast ? trailingExtent : 0);
      final normalized = buildGeometry(spans: geometry.spans, height: height);
      if (normalized.spans.isEmpty) continue;

      final normalizedSnapshot = ChapterLayoutSnapshot(
        reference: snapshot.reference,
        top: snapshot.top,
        height: snapshot.height,
        geometry: normalized,
        firstVerse: normalized.firstVerse,
        lastVerse: normalized.lastVerse,
      );
      _chaptersByKey[_chapterKey(
            normalizedSnapshot.bookId,
            normalizedSnapshot.chapter,
          )] =
          normalizedSnapshot;

      _blocks.addAll(
        _piecesForChapter(normalizedSnapshot, height).map(
          (piece) => SyncLayoutBlock(
            start: piece.start,
            end: piece.end,
            from: piece.from,
            to: piece.to,
            verse: piece.verse,
          ),
        ),
      );
    }
  }

  List<_RawPiece> _piecesForChapter(
    ChapterLayoutSnapshot snapshot,
    double height,
  ) {
    final geometry = snapshot.geometry;
    if (geometry == null || geometry.spans.isEmpty) return const [];

    final chapterStart = snapshot.top;
    final orderedSpans = geometry.spans.values.toList()
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : a.verse.compareTo(b.verse);
      });

    final pieces = <_RawPiece>[];
    for (final span in orderedSpans) {
      if (span.start >= height - _eps) continue;

      final start = span.start.clamp(0.0, height);
      final end = span.end.clamp(start, height);
      final verseRef = Reference(
        bookId: snapshot.bookId,
        chapter: snapshot.chapter,
        verse: span.verse,
      );

      pieces.add(
        _RawPiece(
          start: chapterStart + start,
          end: chapterStart + end,
          verse: verseRef,
          from: Anchor(verseRef, AnchorEnd.start),
          to: Anchor(verseRef, AnchorEnd.end),
        ),
      );
    }

    return pieces;
  }

  /// The block containing [y] in scroll coordinates.
  SyncLayoutBlock? blockAt(double y) {
    if (_blocks.isEmpty) return null;
    for (final block in _blocks) {
      if (y < block.start - _eps) return null;
      if (block.end > y + _eps) {
        return block;
      }
    }
    return y <= _blocks.last.end + _eps ? _blocks.last : null;
  }

  /// Resolves a leader report at [viewportTop].
  SyncLeaderInfo? leaderAt(double viewportTop, double viewportHeight) {
    final block = blockAt(viewportTop);
    if (block == null) return null;

    final t = block.height > _eps
        ? ((viewportTop - block.start) / block.height).clamp(0.0, 1.0)
        : 0.0;
    final viewportBottom = viewportTop + viewportHeight;

    Reference? display;
    for (final candidate in _blocks) {
      if (candidate.start > viewportBottom + _eps) break;
      if (!candidate.isVerse) continue;
      if (candidate.start >= viewportTop - _eps &&
          candidate.end <= viewportBottom + _eps) {
        display = candidate.verse;
        break;
      }
    }

    display ??= block.verse ?? block.to.ref ?? block.from.ref;

    return SyncLeaderInfo(
      position: SyncPosition(block.from, block.to, t),
      displayReference: display,
    );
  }

  /// Resolves an anchor in this layout, or null when its chapter/geometry is
  /// not available yet.
  double? resolveAnchor(Anchor anchor) {
    if (anchor.ref == null) {
      if (_blocks.isEmpty) return null;
      return anchor.isTop ? _blocks.first.start : _blocks.last.end;
    }

    final ref = anchor.ref!;
    final snapshot = chapterFor(ref.bookId, ref.chapter);
    final geometry = snapshot?.geometry;
    if (snapshot == null || geometry == null) return null;

    final span = geometry.spans[ref.verse];
    if (span != null) {
      return snapshot.top +
          (anchor.end == AnchorEnd.end ? span.end : span.start);
    }

    int? next;
    for (final candidate in geometry.spans.keys) {
      if (candidate > ref.verse && (next == null || candidate < next)) {
        next = candidate;
      }
    }
    if (next == null) return null;
    return snapshot.top + geometry.spans[next]!.start;
  }

  /// Resolves both anchors and interpolates by [SyncPosition.t].
  double? resolvePosition(SyncPosition position) {
    final from = resolveAnchor(position.from);
    final to = resolveAnchor(position.to);
    if (from == null || to == null) return null;
    final low = math.min(from, to);
    final high = math.max(from, to);
    return low + (high - low) * position.t;
  }

  /// The chapter a position is currently inside, used to re-center a panel.
  Reference? chapterForPosition(SyncPosition position) {
    final from = position.from.ref;
    final to = position.to.ref;

    Reference? chosen;
    if (from != null && to != null) {
      if (from.bookId == to.bookId && from.chapter == to.chapter) {
        chosen = from;
      } else {
        chosen = position.t < 0.5 ? from : to;
      }
    } else {
      chosen = from ?? to;
    }

    if (chosen == null) return null;
    return Reference(bookId: chosen.bookId, chapter: chosen.chapter, verse: 1);
  }
}

class _RawPiece {
  const _RawPiece({
    required this.start,
    required this.end,
    required this.from,
    required this.to,
    required this.verse,
  });

  final double start;
  final double end;
  final Anchor from;
  final Anchor to;
  final Reference verse;
}
