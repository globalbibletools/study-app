import 'reference.dart';

class HebrewGreekWord {
  /// Opaque word identifier.
  ///
  /// Currently the packed string `BBCCCVVVWW`, but callers must not decode
  /// it. The word's verse reference is available via [reference].
  final String id;

  /// The book/chapter/verse this word belongs to.
  final Reference reference;

  final String text;
  final String? strongsCode;

  HebrewGreekWord({
    required this.id,
    required this.reference,
    required this.text,
    this.strongsCode,
  });

  @override
  String toString() =>
      'HebrewGreekWord(id: $id, reference: $reference, text: $text)';
}
