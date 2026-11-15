import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/ui/home/common/scroll_sync_controller.dart';

/// How precisely a [VerseSpan] was measured.
enum SpanKind {
  /// Anchors come from real, measured layout positions.
  exact,

  /// The verse shares a line/paragraph with a later verse, so it has no height
  /// of its own.
  zero,

  /// Anchors were derived by evenly dividing a paragraph between its verses.
  virtual,
}

/// The vertical extent of a single verse inside a chapter.
@immutable
class VerseSpan {
  const VerseSpan({
    required this.verse,
    required this.start,
    required this.end,
    required this.kind,
  });

  final int verse;

  /// Chapter-relative y of the top of the verse.
  final double start;

  /// Chapter-relative y of the bottom of the verse.
  final double end;

  final SpanKind kind;

  double get height => end - start;

  bool get isZeroHeight => end <= start;

  @override
  String toString() => 'VerseSpan($verse, $start..$end, $kind)';
}

/// A non-verse region inside a chapter (title, padding, paragraph spacing...).
@immutable
class GapSpan {
  const GapSpan({
    required this.start,
    required this.end,
    this.fromVerse,
    this.toVerse,
  });

  /// Chapter-relative y of the top of the gap.
  final double start;

  /// Chapter-relative y of the bottom of the gap.
  final double end;

  /// The verse before the gap, or null when the gap touches the chapter top.
  final int? fromVerse;

  /// The verse after the gap, or null when the gap touches the chapter bottom.
  final int? toVerse;

  double get height => end - start;

  @override
  String toString() => 'GapSpan($start..$end, $fromVerse -> $toVerse)';
}

/// Measured verse/gap geometry for one chapter, in chapter-local coordinates.
@immutable
class ChapterGeometry {
  const ChapterGeometry({required this.spans, required this.gaps});

  /// Verse number to its measured span.
  final Map<int, VerseSpan> spans;

  /// Gap regions, ordered by [GapSpan.start].
  final List<GapSpan> gaps;

  int? get firstVerse =>
      spans.isEmpty ? null : spans.keys.reduce((a, b) => a < b ? a : b);

  int? get lastVerse =>
      spans.isEmpty ? null : spans.keys.reduce((a, b) => a > b ? a : b);

  /// Moves all coordinates down by [dy].
  ChapterGeometry translated(double dy) {
    if (dy == 0) return this;
    return ChapterGeometry(
      spans: {
        for (final entry in spans.entries)
          entry.key: VerseSpan(
            verse: entry.value.verse,
            start: entry.value.start + dy,
            end: entry.value.end + dy,
            kind: entry.value.kind,
          ),
      },
      gaps: [
        for (final gap in gaps)
          GapSpan(
            start: gap.start + dy,
            end: gap.end + dy,
            fromVerse: gap.fromVerse,
            toVerse: gap.toVerse,
          ),
      ],
    );
  }
}

/// Contract implemented by chapter widgets that can report their geometry.
mixin ChapterGeometryProvider {
  /// Null until the chapter is loaded and has been laid out at least once.
  ChapterGeometry? get geometry;
}

/// Dispatched by a chapter after its geometry has been (re)measured.
class ChapterGeometryChangedNotification extends Notification {
  const ChapterGeometryChangedNotification();
}

/// A laid-out chapter as seen by the panel.
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

  /// Reference to the chapter. The verse is normally 1.
  final Reference reference;

  /// Global (scroll-coordinate) y of the top of the chapter.
  final double top;

  /// Extent of the chapter in the scroll view.
  final double height;

  final ChapterGeometry? geometry;

  /// First/last verse known from navigation, used when [geometry] is absent.
  final int? firstVerse;
  final int? lastVerse;

  int get bookId => reference.bookId;
  int get chapter => reference.chapter;
}

/// One resolved unit in a stitched, multi-chapter layout.
@immutable
class SyncLayoutBlock {
  const SyncLayoutBlock({
    required this.start,
    required this.end,
    required this.from,
    required this.to,
    this.verse,
    this.kind,
  });

  /// Global y of the top of this block.
  final double start;

  /// Global y of the bottom of this block.
  final double end;

  final Anchor from;
  final Anchor to;

  /// Full reference when this is a verse block, null for a gap.
  final Reference? verse;

  /// Measurement quality for verse blocks.
  final SpanKind? kind;

  bool get isVerse => verse != null;
  bool get isGap => verse == null;
  double get height => end - start;

  @override
  String toString() =>
      'SyncLayoutBlock($start..$end, ${verse ?? 'gap'}, $from -> $to)';
}

/// Result of asking a layout where the leader is.
@immutable
class SyncLeaderInfo {
  const SyncLeaderInfo({
    required this.position,
    required this.displayReference,
  });

  final SyncPosition position;

  /// The first fully visible verse, or the fallback verse for the block.
  final Reference? displayReference;
}

/// A single line as produced by a custom text renderer.
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

const double _eps = 0.01;

/// Derives verse spans and gaps from line ownership.
///
/// Each line is owned by the last verse that starts on it. Lines where no verse
/// starts extend the previous owner. A verse that owns no lines gets a
/// zero-height span at the top of the line where it starts.
ChapterGeometry geometryFromLines(
  List<LineLayout> lines, {
  Iterable<int>? allVerses,
  double? height,
}) {
  final spans = <int, VerseSpan>{};
  final contentHeight = height ?? (lines.isEmpty ? 0.0 : lines.last.bottom);

  final startLineByVerse = <int, int>{};
  for (var i = 0; i < lines.length; i++) {
    for (final verse in lines[i].startingVerses) {
      startLineByVerse.putIfAbsent(verse, () => i);
    }
  }

  final ownerOfLine = List<int?>.filled(lines.length, null);
  int? currentOwner;
  for (var i = 0; i < lines.length; i++) {
    final starts = lines[i].startingVerses;
    if (starts.isNotEmpty) currentOwner = starts.last;
    ownerOfLine[i] = currentOwner;
  }

  final firstOwnedLine = <int, int>{};
  final lastOwnedLine = <int, int>{};
  for (var i = 0; i < lines.length; i++) {
    final owner = ownerOfLine[i];
    if (owner == null) continue;
    firstOwnedLine.putIfAbsent(owner, () => i);
    lastOwnedLine[owner] = i;
  }

  final verses = <int>{
    ...?allVerses,
    ...startLineByVerse.keys,
    ...firstOwnedLine.keys,
  }.toList()..sort();

  for (final verse in verses) {
    final startLine = startLineByVerse[verse];
    final firstOwned = firstOwnedLine[verse];
    final lastOwned = lastOwnedLine[verse];

    if (firstOwned != null && lastOwned != null) {
      final start = lines[firstOwned].top;
      final end = lines[lastOwned].bottom;
      spans[verse] = VerseSpan(
        verse: verse,
        start: start,
        end: end,
        kind: end - start <= _eps ? SpanKind.zero : SpanKind.exact,
      );
    } else {
      final y = startLine == null ? contentHeight : lines[startLine].top;
      spans[verse] = VerseSpan(
        verse: verse,
        start: y,
        end: y,
        kind: SpanKind.zero,
      );
    }
  }

  return ChapterGeometry(spans: spans, gaps: _deriveGaps(spans, contentHeight));
}

/// Builds gap spans for the parts of `[0, height]` not covered by verses.
List<GapSpan> deriveGapSpans(Map<int, VerseSpan> spans, double height) =>
    _deriveGaps(spans, height);

/// A heading block (chapter title or section heading) rendered above a verse.
@immutable
class HeadingRect {
  const HeadingRect({required this.top, required this.bottom});

  /// Chapter-relative y of the top of the heading.
  final double top;

  /// Chapter-relative y of the bottom of the heading.
  final double bottom;

  double get height => bottom - top;

  @override
  String toString() => 'HeadingRect($top..$bottom)';
}

/// Builds chapter geometry, attributing [headings] to the verses they
/// introduce.
///
/// A heading (chapter title, section heading) belongs to the verse that
/// follows it: that verse's span starts at the top of its topmost heading, so
/// the heading traverses as part of the verse during sync and a jump to the
/// verse reveals the heading. Only the blank space around headings remains
/// as gap. Headings with no following verse stay gap content.
ChapterGeometry buildGeometry({
  required Map<int, VerseSpan> spans,
  required double height,
  List<HeadingRect> headings = const [],
}) {
  if (headings.isEmpty) {
    return ChapterGeometry(spans: spans, gaps: _deriveGaps(spans, height));
  }

  final ordered = spans.values.toList()
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.verse.compareTo(b.verse);
    });
  final sortedHeadings = headings.toList()
    ..sort((a, b) => a.top.compareTo(b.top));

  final adjusted = {for (final span in ordered) span.verse: span};

  for (final heading in sortedHeadings) {
    // The verse the heading introduces: the first span at or below the
    // heading's bottom.
    VerseSpan? followed;
    for (final span in ordered) {
      if (span.start >= heading.bottom - _eps) {
        followed = span;
        break;
      }
    }
    if (followed == null) continue; // Trailing heading stays gap content.
    if (heading.top >= followed.start - _eps) continue; // Defensive.

    final current = adjusted[followed.verse]!;
    adjusted[followed.verse] = VerseSpan(
      verse: followed.verse,
      start: math.min(current.start, heading.top),
      end: current.end,
      kind: current.kind,
    );
  }

  return ChapterGeometry(
    spans: adjusted,
    gaps: _deriveGaps(adjusted, height),
  );
}

List<GapSpan> _deriveGaps(Map<int, VerseSpan> spans, double height) {
  if (spans.isEmpty) {
    return height > 0 ? [GapSpan(start: 0, end: height)] : const <GapSpan>[];
  }

  final ordered = spans.values.toList()
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.verse.compareTo(b.verse);
    });
  final gaps = <GapSpan>[];

  var previousEnd = 0.0;
  int? previousVerse;

  for (final span in ordered) {
    if (span.start > previousEnd + _eps) {
      gaps.add(
        GapSpan(
          start: previousEnd,
          end: span.start,
          fromVerse: previousVerse,
          toVerse: span.verse,
        ),
      );
    }
    previousEnd = math.max(previousEnd, span.end);
    previousVerse = span.verse;
  }

  if (height > previousEnd + _eps) {
    gaps.add(
      GapSpan(start: previousEnd, end: height, fromVerse: previousVerse),
    );
  }

  return gaps;
}

/// A stitched, multi-chapter layout used by both the leader and the follower.
class SyncLayout {
  SyncLayout(this.chapters, {double trailingExtent = 0}) {
    _build(trailingExtent);
  }

  final List<ChapterLayoutSnapshot> chapters;
  final List<SyncLayoutBlock> _blocks = [];
  final Map<int, ChapterLayoutSnapshot> _chaptersByKey = {};

  /// Gap heights adjacent to each verse block (keyed by verse reference),
  /// used by gap absorption in [resolvePosition].
  final Map<int, double> _gapBeforeByVerse = {};
  final Map<int, double> _gapAfterByVerse = {};

  /// Blocks in document order, tiling the measured content.
  List<SyncLayoutBlock> get blocks => List.unmodifiable(_blocks);

  bool get isEmpty => _blocks.isEmpty;

  int _chapterKey(int bookId, int chapter) => bookId * 1000 + chapter;

  ChapterLayoutSnapshot? chapterFor(int bookId, int chapter) =>
      _chaptersByKey[_chapterKey(bookId, chapter)];

  void _build(double trailingExtent) {
    for (final snapshot in chapters) {
      _chaptersByKey[_chapterKey(snapshot.bookId, snapshot.chapter)] = snapshot;
    }

    final pieces = <_RawPiece>[];

    for (var i = 0; i < chapters.length; i++) {
      final snapshot = chapters[i];
      final isLast = i == chapters.length - 1;
      final height = snapshot.height + (isLast ? trailingExtent : 0);
      pieces.addAll(_piecesForChapter(snapshot, height));
    }

    // Merge adjacent gaps. This joins a chapter's trailing gap with the next
    // chapter's leading gap into one cross-chapter gap.
    final merged = <_RawPiece>[];
    for (final piece in pieces) {
      if (piece.isGap &&
          merged.isNotEmpty &&
          merged.last.isGap &&
          (piece.start - merged.last.end).abs() <= _eps) {
        final previous = merged.removeLast();
        merged.add(
          _RawPiece(
            start: previous.start,
            end: piece.end,
            from: previous.from ?? piece.from,
            to: piece.to ?? previous.to,
          ),
        );
      } else {
        merged.add(piece);
      }
    }

    // Fill any remaining open side from the nearest verse block, then map the
    // book extremes to null anchors.
    for (var i = 0; i < merged.length; i++) {
      final piece = merged[i];
      if (!piece.isGap) continue;

      Anchor? from = piece.from;
      Anchor? to = piece.to;

      if (from == null) {
        for (var j = i - 1; j >= 0; j--) {
          final previous = merged[j];
          if (previous.verse != null) {
            from = Anchor(previous.verse, AnchorEnd.end);
            break;
          }
        }
        from ??= const Anchor.top();
      }

      if (to == null) {
        for (var j = i + 1; j < merged.length; j++) {
          final next = merged[j];
          if (next.verse != null) {
            to = Anchor(next.verse, AnchorEnd.start);
            break;
          }
        }
        to ??= const Anchor.bottom();
      }

      merged[i] = _RawPiece(
        start: piece.start,
        end: piece.end,
        from: from,
        to: to,
      );
    }

    _blocks
      ..clear()
      ..addAll(
        merged.map(
          (piece) => SyncLayoutBlock(
            start: piece.start,
            end: piece.end,
            from: piece.from ?? const Anchor.top(),
            to: piece.to ?? const Anchor.bottom(),
            verse: piece.verse,
            kind: piece.kind,
          ),
        ),
      );

    _indexAdjacentGaps();
  }

  void _indexAdjacentGaps() {
    _gapBeforeByVerse.clear();
    _gapAfterByVerse.clear();
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      if (!block.isVerse) continue;
      final key = _refKey(block.verse!);
      if (i > 0 && _blocks[i - 1].isGap) {
        _gapBeforeByVerse[key] = _blocks[i - 1].height;
      }
      if (i + 1 < _blocks.length && _blocks[i + 1].isGap) {
        _gapAfterByVerse[key] = _blocks[i + 1].height;
      }
    }
  }

  int _refKey(Reference ref) =>
      ref.bookId * 1000000 + ref.chapter * 1000 + ref.verse;

  List<_RawPiece> _piecesForChapter(
    ChapterLayoutSnapshot snapshot,
    double height,
  ) {
    final geometry = snapshot.geometry;
    final chapterStart = snapshot.top;

    if (geometry == null || geometry.spans.isEmpty) {
      if (height <= _eps) return const [];
      return [_RawPiece(start: chapterStart, end: chapterStart + height)];
    }

    final orderedSpans = geometry.spans.values.toList()
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : a.verse.compareTo(b.verse);
      });
    final visibleSpans = orderedSpans
        .map((span) {
          final start = span.start.clamp(0.0, height);
          final end = span.end.clamp(start, height);
          return VerseSpan(
            verse: span.verse,
            start: start,
            end: end,
            kind: span.kind,
          );
        })
        .where((span) => span.start < height - _eps)
        .toList();

    if (visibleSpans.isEmpty) {
      if (height <= _eps) return const [];
      return [_RawPiece(start: chapterStart, end: chapterStart + height)];
    }

    final pieces = <_RawPiece>[];
    var previousEnd = 0.0;
    var isFirstSpan = true;

    for (final span in visibleSpans) {
      final start = span.start + chapterStart;
      final end = span.end + chapterStart;
      final verseRef = Reference(
        bookId: snapshot.bookId,
        chapter: snapshot.chapter,
        verse: span.verse,
      );

      if (span.start > previousEnd + _eps) {
        pieces.add(
          _RawPiece(
            start: previousEnd + chapterStart,
            end: start,
            // A leading gap has no anchor of its own; the stitching pass
            // resolves it against the previous chapter's last verse.
            from: isFirstSpan ? null : _verseAnchor(snapshot, previousEnd),
            to: Anchor(verseRef, AnchorEnd.start),
          ),
        );
      }

      pieces.add(
        _RawPiece(
          start: start,
          end: end,
          verse: verseRef,
          kind: span.kind,
          from: Anchor(verseRef, AnchorEnd.start),
          to: Anchor(verseRef, AnchorEnd.end),
        ),
      );

      previousEnd = math.max(previousEnd, span.end);
      isFirstSpan = false;
    }

    if (height > previousEnd + _eps) {
      final lastVerseRef = _lastVerseRef(snapshot);
      pieces.add(
        _RawPiece(
          start: previousEnd + chapterStart,
          end: chapterStart + height,
          from: lastVerseRef == null
              ? null
              : Anchor(lastVerseRef, AnchorEnd.end),
        ),
      );
    }

    return pieces;
  }

  Anchor? _verseAnchor(ChapterLayoutSnapshot snapshot, double localY) {
    final geometry = snapshot.geometry;
    if (geometry == null) return null;

    VerseSpan? match;
    for (final span in geometry.spans.values) {
      if (span.end <= localY + _eps) {
        if (match == null || span.end >= match.end) match = span;
      }
    }
    if (match == null) return null;
    return Anchor(
      Reference(
        bookId: snapshot.bookId,
        chapter: snapshot.chapter,
        verse: match.verse,
      ),
      AnchorEnd.end,
    );
  }

  Reference? _lastVerseRef(ChapterLayoutSnapshot snapshot) {
    final lastVerse = snapshot.geometry?.lastVerse ?? snapshot.lastVerse;
    if (lastVerse == null) return null;
    return Reference(
      bookId: snapshot.bookId,
      chapter: snapshot.chapter,
      verse: lastVerse,
    );
  }

  /// The block containing [y] in scroll coordinates.
  SyncLayoutBlock? blockAt(double y) {
    if (_blocks.isEmpty) return null;
    for (final block in _blocks) {
      if (block.end > y + _eps) {
        return block;
      }
    }
    return _blocks.last;
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
  ///
  /// This is the raw, unexpanded resolution: verse edges resolve to their
  /// measured span edges and missing verses park at the previous verse that
  /// exists. See [_resolveAnchorExpanded] for the smoothed resolution used by
  /// [resolvePosition].
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

    // Missing verse: park at the end of the previous verse that exists.
    final (previous, next) = _missingNeighbors(geometry, ref.verse);
    if (previous != null) {
      return snapshot.top + geometry.spans[previous]!.end;
    }
    if (next != null) {
      return snapshot.top + geometry.spans[next]!.start;
    }
    return snapshot.top;
  }

  (int?, int?) _missingNeighbors(ChapterGeometry geometry, int verse) {
    int? previous;
    int? next;
    for (final candidate in geometry.spans.keys) {
      if (candidate < verse && (previous == null || candidate > previous)) {
        previous = candidate;
      }
      if (candidate > verse && (next == null || candidate < next)) {
        next = candidate;
      }
    }
    return (previous, next);
  }

  /// Resolves both anchors and interpolates by [SyncPosition.t].
  ///
  /// Anchors expand outward by half the gap adjacent to them in THIS layout
  /// (gap absorption), so a gap that exists only on this panel is traversed
  /// gradually while the leader scrolls the neighboring verse, instead of
  /// being jumped over at the verse boundary. Consequences:
  ///
  /// - `t = 1` of a verse and `t = 0` of the next verse meet at the midpoint
  ///   of the gap between them — one pixel, no jump.
  /// - A gap the leader reports resolves to the degenerate band between the
  ///   two half-gaps: the follower holds at the gap's midpoint while the
  ///   leader crosses its own gap.
  /// - A missing verse parks at the expanded end of the previous existing
  ///   verse, so a run of missing verses holds at one point and hands off
  ///   continuously to the next existing verse.
  double? resolvePosition(SyncPosition position) {
    final from = _resolveAnchorExpanded(position.from);
    final to = _resolveAnchorExpanded(position.to);
    if (from == null || to == null) return null;
    final low = math.min(from, to);
    final high = math.max(from, to);
    return low + (high - low) * position.t;
  }

  /// Resolves an anchor expanded outward by half its adjacent gap.
  double? _resolveAnchorExpanded(Anchor anchor) {
    if (anchor.ref == null) return resolveAnchor(anchor);

    final ref = anchor.ref!;
    final snapshot = chapterFor(ref.bookId, ref.chapter);
    final geometry = snapshot?.geometry;
    if (snapshot == null || geometry == null) return null;

    final span = geometry.spans[ref.verse];
    if (span != null) {
      final raw =
          snapshot.top +
          (anchor.end == AnchorEnd.end ? span.end : span.start);
      final key = _refKey(ref);
      return anchor.end == AnchorEnd.end
          ? raw + (_gapAfterByVerse[key] ?? 0) / 2
          : raw - (_gapBeforeByVerse[key] ?? 0) / 2;
    }

    // Missing verse: park like resolveAnchor, expanded the same way the
    // neighboring existing anchor expands, so handoffs stay continuous.
    final (previous, next) = _missingNeighbors(geometry, ref.verse);

    if (previous != null) {
      final previousKey = _refKey(
        Reference(bookId: ref.bookId, chapter: ref.chapter, verse: previous),
      );
      final raw = snapshot.top + geometry.spans[previous]!.end;
      return raw + (_gapAfterByVerse[previousKey] ?? 0) / 2;
    }
    if (next != null) {
      final nextKey = _refKey(
        Reference(bookId: ref.bookId, chapter: ref.chapter, verse: next),
      );
      final raw = snapshot.top + geometry.spans[next]!.start;
      return raw - (_gapBeforeByVerse[nextKey] ?? 0) / 2;
    }
    return snapshot.top;
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
    this.from,
    this.to,
    this.verse,
    this.kind,
  });

  final double start;
  final double end;
  final Anchor? from;
  final Anchor? to;
  final Reference? verse;
  final SpanKind? kind;

  bool get isGap => verse == null;
}
