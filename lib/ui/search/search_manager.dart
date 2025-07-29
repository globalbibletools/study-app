import 'package:database_builder/database_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class SearchPageManager {
  final candidatesNotifier = ValueNotifier<List<String>>([]);
  final verseResultsNotifier = ValueNotifier<VerseSearchResults?>(null);
  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();

  /// Finds a list of words from the Hebrew/Greek database that start with
  /// the given [prefix] at the cursor position.
  Future<void> searchWordPrefixAtCursor(TextEditingValue value) async {
    final prefix = _getWordAtCursor(value);

    if (prefix == null) {
      candidatesNotifier.value = [];
      return;
    }

    final results = await _hebrewGreekDb.getWordsStartingWith(prefix, limit: 3);
    candidatesNotifier.value = results;
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

  TextEditingValue replaceWordAtCursor(TextEditingValue value, String word) {
    final (start, end) = _getWordRangeAtCursor(value);
    final newText = value.text.replaceRange(start, end, word);
    final finalText = fixFinalForms(newText);
    final newCursorOffset = start + word.length;
    return TextEditingValue(
      text: finalText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
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
    verseResultsNotifier.value = VerseSearchResults(
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

  Future<void> saveDirection(TextDirection textDirection) async {
    final isHebrew = textDirection == TextDirection.rtl;
    await getIt<UserSettings>().setIsHebrewSearch(isHebrew);
  }

  TextDirection savedTextDirection() {
    final isHebrew = getIt<UserSettings>().isHebrewSearch;
    return isHebrew ? TextDirection.rtl : TextDirection.ltr;
  }

  void clearCandidateList() {
    candidatesNotifier.value = [];
  }

  void clearVerseResults() {
    verseResultsNotifier.value = null;
  }

  bool shouldUseSystemKeyboard() {
    return getIt<UserSettings>().shouldUseSystemKeyboard;
  }

  Future<void> setUseSystemKeyboard(bool value) async {
    await getIt<UserSettings>().setUseSystemKeyboard(value);
  }
}

class VerseSearchResults {
  VerseSearchResults({required this.searchWords, required this.references});
  final List<String> searchWords;
  final List<Reference> references;

  int get length => references.length;
}
