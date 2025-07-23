import 'package:database_builder/database_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';

class SearchPageManager {
  final resultsNotifier = ValueNotifier<SearchResults>(NoResults());
  // final versesNotifier = ValueNotifier<List<Reference>>([]);

  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();

  Future<void> searchWordPrefix(String prefix) async {
    print('searching for $prefix');
    final results = await _hebrewGreekDb.getWordsStartingWith(
      prefix,
      limit: 100,
    );
    print('results: $results');
    resultsNotifier.value = WordSearchResults(words: results);
  }

  Future<void> searchVerses(String word) async {
    final verseIds = await _hebrewGreekDb.getVerseIdsForNormalizedWord(word);
    final references =
        verseIds.map(extractReferenceFromWordId).toSet().toList();
    resultsNotifier.value = VerseSearchResults(
      searchWord: word,
      references: references,
    );
  }

  /// Returns the the verse text with the words highlighted based on
  /// the Strong's number.
  Future<TextSpan> getVerseContent(
    String searchWord,
    Reference reference,
    Color highlightColor,
    double fontSize,
  ) async {
    final words = await _hebrewGreekDb.wordsForVerse(reference);
    return _formatVerse(words, searchWord, highlightColor, fontSize);
  }

  static const maqaph = '־';

  TextSpan _formatVerse(
    List<HebrewGreekWord> words,
    String searchWord,
    Color highlightColor,
    double fontSize,
  ) {
    final spans = <TextSpan>[];
    for (final word in words) {
      final normalized = filterAllButHebrewGreekNoDiacritics(word.text);
      final color = (normalized == searchWord) ? highlightColor : null;
      final text = word.text.endsWith(maqaph) ? word.text : '${word.text} ';
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'sbl', color: color, fontSize: fontSize),
        ),
      );
    }
    return TextSpan(children: spans);
  }
}

sealed class SearchResults {
  int get length;
}

class NoResults extends SearchResults {
  @override
  int get length => 0;
}

class WordSearchResults extends SearchResults {
  WordSearchResults({required this.words});
  final List<String> words;
  @override
  int get length => words.length;
}

class VerseSearchResults extends SearchResults {
  VerseSearchResults({required this.searchWord, required this.references});
  final String searchWord;
  final List<Reference> references;
  @override
  int get length => references.length;
}
