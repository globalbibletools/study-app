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
    if (prefix.length == 1) {
      resultsNotifier.value = WordSearchResults(words: [prefix]);
      return;
    }

    final results = await _hebrewGreekDb.getWordsStartingWith(
      prefix,
      limit: 1000,
    );
    print('results: ${results.length}');
    results.sort((a, b) => a.length.compareTo(b.length));
    resultsNotifier.value = WordSearchResults(words: results);
  }

  Future<void> searchVerses(String word) async {
    final normalized = normalizeHebrewGreek(word);
    final verseIds = await _hebrewGreekDb.getVerseIdsForNormalizedWord(
      normalized,
    );
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
    final normalizedSearch = normalizeHebrewGreek(searchWord);
    for (final word in words) {
      final normalized = normalizeHebrewGreek(word.text);
      final color = (normalized == normalizedSearch) ? highlightColor : null;
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

  /// Automatically replaces Hebrew letters with their final-form counterparts
  /// (sofit) at the end of words, and corrects final-form letters that are
  /// mistakenly used in the middle of a word. Letters in isolation stay in regular form.
  String fixHebrewFinalForms(String text) {
    const finalLetterMap = {
      'כ': 'ך', // Kaf -> Final Kaf
      'מ': 'ם', // Mem -> Final Mem
      'נ': 'ן', // Nun -> Final Nun
      'פ': 'ף', // Pe -> Final Pe
      'צ': 'ץ', // Tsadi -> Final Tsadi
    };

    const regularLetterMap = {
      'ך': 'כ', // Final Kaf -> Kaf
      'ם': 'מ', // Final Mem -> Mem
      'ן': 'נ', // Final Nun -> Nun
      'ף': 'פ', // Final Pe -> Pe
      'ץ': 'צ', // Final Tsadi -> Tsadi
    };

    // Regex to find sequences of Hebrew letters.
    final RegExp wordRegex = RegExp(r'([\u0590-\u05FF]+)', unicode: true);

    return text.replaceAllMapped(wordRegex, (match) {
      final word = match.group(1)!;

      // Rule: Single-letter words should always be in regular form.
      if (word.length == 1) {
        // If it's a final-form letter, convert it back to regular.
        return regularLetterMap[word] ?? word;
      }

      // For words with more than one letter:
      String middle = word.substring(0, word.length - 1);
      String lastChar = word[word.length - 1];

      // Rule: All letters in the middle of a word must be in regular form.
      // We replace any final-form letter found with its regular counterpart.
      middle = middle.replaceAllMapped(RegExp('[ךםןףץ]'), (m) {
        return regularLetterMap[m.group(0)!]!;
      });

      // Rule: The last letter of a word should be in final form if it has one.
      // If the last character is a letter that has a final form, convert it.
      if (finalLetterMap.containsKey(lastChar)) {
        lastChar = finalLetterMap[lastChar]!;
      }

      return middle + lastChar;
    });
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
