import 'package:database_builder/database_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/ui/home/similar_verses/similar_verses_page.dart';
import 'package:studyapp/ui/home/word_details_dialog/dialog_manager.dart';

class SimilarVerseManager {
  final _db = getIt<HebrewGreekDatabase>();
  final similarVersesNotifier = ValueNotifier<List<Reference>>([]);

  Future<void> search(WordDetails word, SearchType searchType) async {
    List<int> verseIds;
    if (searchType == SearchType.root) {
      verseIds = await _db.allWordsForStrongsCode(word.strongsCode);
    } else {
      verseIds = await _db.searchExactMatchNoPunctuation(word.word);
    }
    final references =
        verseIds.map(extractReferenceFromWordId).toSet().toList();
    similarVersesNotifier.value = references;
  }

  Future<TextSpan> getVerseContent(
    Reference reference,
    WordDetails word,
    SearchType searchType,
    Color highlightColor,
    double fontSize,
  ) async {
    final List<HebrewGreekWord> words = await _db.wordsForVerse(
      reference,
      includeStrongs: true,
    );
    return _formatVerse(words, word, searchType, highlightColor, fontSize);
  }

  static const maqaph = '־';

  TextSpan _formatVerse(
    List<HebrewGreekWord> words,
    WordDetails pressedWord,
    SearchType searchType,
    Color highlightColor,
    double fontSize,
  ) {
    final spans = <TextSpan>[];
    for (final word in words) {
      final Color? color;
      if (searchType == SearchType.exact) {
        color =
            (removePunctuation(word.text) ==
                    removePunctuation(pressedWord.word))
                ? highlightColor
                : null;
      } else {
        color =
            (word.strongsCode == pressedWord.strongsCode)
                ? highlightColor
                : null;
      }

      final text = word.text.endsWith(maqaph) ? word.text : '${word.text} ';
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: fontSize),
        ),
      );
    }
    return TextSpan(children: spans);
  }
}
