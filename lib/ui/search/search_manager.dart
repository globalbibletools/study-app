import 'package:database_builder/database_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';

class SearchPageManager {
  final resultsNotifier = ValueNotifier<SearchResults>(NoResults());
  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();

  /// Finds a list of words from the Hebrew/Greek database that start with
  /// the given [prefix] at the cursor position.
  Future<void> searchWordPrefix(TextEditingValue value) async {
    final prefix = _getWordAtCursor(value);

    if (prefix == null) {
      resultsNotifier.value = NoResults();
      return;
    }

    if (prefix.length == 1) {
      resultsNotifier.value = WordSearchResults(words: [prefix]);
      return;
    }

    final results = await _hebrewGreekDb.getWordsStartingWith(
      prefix,
      limit: 1000,
    );
    results.sort((a, b) => a.length.compareTo(b.length));
    resultsNotifier.value = WordSearchResults(words: results);
  }

  String? _getWordAtCursor(TextEditingValue value) {
    final (wordStart, wordEnd) = _getWordRangeAtCursor(value);
    String text = value.text;

    if (wordStart < wordEnd) {
      return text.substring(wordStart, wordEnd);
    }

    return null;
  }

  (int start, int end) _getWordRangeAtCursor(TextEditingValue value) {
    int cursorPos = value.selection.baseOffset;

    // If there is a selection, don't look for the word
    if (!value.selection.isCollapsed) {
      return (cursorPos, cursorPos);
    }

    const String space = ' ';
    String text = value.text;

    if (cursorPos < 0 || cursorPos > text.length || text.isEmpty) {
      return (cursorPos, cursorPos);
    }

    int wordStart = cursorPos;
    int wordEnd = cursorPos;

    for (int i = wordEnd; i < text.length; i++) {
      if (text[i] == space) break;
      wordEnd = i + 1;
    }

    for (int i = wordStart - 1; i >= 0; i--) {
      if (text[i] == space) break;
      wordStart = i;
    }

    return (wordStart, wordEnd);
  }

  String replaceWordAtCursor(TextEditingValue value, String word) {
    final (start, end) = _getWordRangeAtCursor(value);
    final text = value.text;
    final replaced = text.replaceRange(start, end, word);
    return fixHebrewFinalForms(replaced);
  }

  /// Updates the [VerseSearchResults] with verses than contain an exact
  /// match for all normalized words.
  ///
  /// If the [searchPhrase] contains spaces, then each word in the phrase must
  /// be somewhere in the verse.
  Future<void> searchVerses(String searchPhrase) async {
    final String normalizedPhrase = normalizeHebrewGreek(searchPhrase);
    final List<String> searchWords = normalizedPhrase.split(' ');
    final List<Reference> results = await _hebrewGreekDb
        .searchVersesByNormalizedWords(searchWords);
    resultsNotifier.value = VerseSearchResults(
      searchWords: searchWords,
      references: results,
    );
  }

  /// Returns the the verse text with the words highlighted based on
  /// the Strong's number.
  Future<TextSpan> getVerseContent(
    List<String> searchWords,
    Reference reference,
    Color highlightColor,
    double fontSize,
  ) async {
    final words = await _hebrewGreekDb.wordsForVerse(reference);
    return _formatVerse(words, searchWords, highlightColor, fontSize);
  }

  static const maqaph = '־';

  TextSpan _formatVerse(
    List<HebrewGreekWord> words,
    List<String> searchWords,
    Color highlightColor,
    double fontSize,
  ) {
    final spans = <TextSpan>[];
    for (final word in words) {
      final normalized = normalizeHebrewGreek(word.text);
      final color = (searchWords.contains(normalized)) ? highlightColor : null;
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
  VerseSearchResults({required this.searchWords, required this.references});
  final List<String> searchWords;
  final List<Reference> references;
  @override
  int get length => references.length;
}
