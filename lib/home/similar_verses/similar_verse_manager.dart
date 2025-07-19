import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';

class SimilarVerseManager {
  final _db = getIt<HebrewGreekDatabase>();
  final similarVersesNotifier = ValueNotifier<List<Reference>>([]);

  Future<void> init(String strongsCode) async {
    final verses = await _db.allWordsForStrongsCode(strongsCode);
    final references =
        verses.map((wordId) {
          final (bookId, chapter, verse, _) = extractReferenceFromWordId(
            wordId,
          );
          return Reference(bookId: bookId, chapter: chapter, verse: verse);
        }).toList();
    similarVersesNotifier.value = references;
  }

  /// Returns the the verse text with the words highlighted based on
  /// the Strong's number.
  Future<TextSpan> getVerseContent(
    Reference reference,
    String strongsCode,
    Color highlightColor,
  ) async {
    final List<HebrewGreekWord> words = await _db.wordsForVerseWithStrongsCode(
      reference,
    );
    return _formatVerse(words, strongsCode, highlightColor);
  }

  TextSpan _formatVerse(
    List<HebrewGreekWord> words,
    String strongsCode,
    Color highlightColor,
  ) {
    final spans = <TextSpan>[];
    for (final word in words) {
      final color = (word.strongsCode == strongsCode) ? highlightColor : null;
      spans.add(
        TextSpan(
          text: '${word.text} ',
          style: TextStyle(fontFamily: 'sbl', color: color),
        ),
      );
    }
    return TextSpan(children: spans);
  }
}
