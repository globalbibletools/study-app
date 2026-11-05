class Reference {
  const Reference({
    required this.bookId,
    required this.chapter,
    required this.verse,
    this.endVerse,
  }) : assert(bookId >= 1 && bookId <= 66),
       assert(chapter >= 1 && chapter <= 150),
       assert(endVerse == null || verse <= endVerse);

  final int bookId;
  final int chapter;
  final int verse;

  /// If not null, the reference is a range of verses.
  final int? endVerse;

  /// Encodes this reference into a 32-bit BBCCCVVV integer:
  /// `bookId * 1000000 + chapter * 1000 + verse`.
  int get toPackedInt => bookId * 1000000 + chapter * 1000 + verse;

  /// Decodes a 32-bit BBCCCVVV integer back into a [Reference].
  factory Reference.fromPackedInt(int packed) {
    final bookId = packed ~/ 1000000;
    final remainder = packed % 1000000;
    final chapter = remainder ~/ 1000;
    final verse = remainder % 1000;
    return Reference(bookId: bookId, chapter: chapter, verse: verse);
  }

  @override
  String toString() {
    return '$bookId $chapter:$verse${endVerse == null ? '' : '–$endVerse'}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Reference &&
        other.bookId == bookId &&
        other.chapter == chapter &&
        other.verse == verse &&
        other.endVerse == endVerse;
  }

  @override
  int get hashCode => Object.hash(bookId, chapter, verse, endVerse);
}
