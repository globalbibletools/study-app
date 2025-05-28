class HebrewGreekWord {
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
