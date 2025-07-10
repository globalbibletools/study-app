class HebrewGreekWord {
  /// ID is in the form of BBCCCVVVWW,
  /// where BB is the book number,
  /// CC is the chapter number,
  /// VVV is the verse number,
  /// and WW is the word number.
  final int id;
  final String text;

  HebrewGreekWord({required this.id, required this.text});

  @override
  String toString() => 'HebrewGreekWord(id: $id, text: $text)';
}
