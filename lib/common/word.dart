class HebrewGreekWord {
  /// ID is in the form of BBCCCVVVWW,
  /// where BB is the book number,
  /// CC is the chapter number,
  /// VVV is the verse number,
  /// and WW is the word number.
  final int id;
  final String text;
  final String? strongsCode;

  HebrewGreekWord({required this.id, required this.text, this.strongsCode});

  @override
  String toString() => 'HebrewGreekWord(id: $id, text: $text)';
}

(int bookId, int chapter, int verse, int word) extractReferenceFromWordId(
  int wordId,
) {
  final word = wordId % 100;
  final verse = (wordId ~/ 100) % 1000;
  final chapter = (wordId ~/ 100000) % 1000;
  final bookId = wordId ~/ 100000000;
  return (bookId, chapter, verse, word);
}
