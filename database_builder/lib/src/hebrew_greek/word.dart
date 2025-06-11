class HebrewGreekWord {
  /// ID is in the form of BBCCCVVVWW,
  /// where BB is the book number,
  /// CC is the chapter number,
  /// VVV is the verse number,
  /// and WW is the word number.
  final int id;
  final String text;
  final String grammar;
  final String lemma;

  HebrewGreekWord({
    required this.id,
    required this.text,
    required this.grammar,
    required this.lemma,
  });

  factory HebrewGreekWord.fromJson(Map<String, dynamic> json) {
    return HebrewGreekWord(
      id: int.parse(json['id']),
      text: json['text']?.trim(),
      grammar: json['grammar']?.trim(),
      lemma: json['lemma']?.trim(),
    );
  }

  @override
  String toString() =>
      'HebrewGreekWord(id: $id, text: $text, grammar: $grammar, lemma: $lemma)';
}
