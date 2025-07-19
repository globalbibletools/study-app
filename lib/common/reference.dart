class Reference {
  Reference({
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

  @override
  String toString() {
    return '$bookId $chapter:$verse${endVerse == null ? '' : '–$endVerse'}';
  }
}
