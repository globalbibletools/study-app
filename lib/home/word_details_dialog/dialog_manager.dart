import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';

class WordDetailsDialogManager {
  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();
  final _glossService = getIt<GlossService>();

  Future<WordDetails> getWordDetails(Locale uiLocale, int wordId) async {
    final word = await _hebrewGreekDb.getWordForId(wordId);
    final gloss = await _glossService.glossForId(
      locale: uiLocale,
      wordId: wordId,
    );
    final (strongs, grammar) =
        await _hebrewGreekDb.getStrongsAndGrammar(wordId) ?? ('', '');
    return WordDetails(
      word: word ?? '',
      gloss: gloss ?? '',
      strongsCode: strongs,
      grammar: grammar,
    );
  }
}

class WordDetails {
  const WordDetails({
    required this.word,
    required this.gloss,
    required this.strongsCode,
    required this.grammar,
  });

  final String word;
  final String gloss;
  final String strongsCode;
  final String grammar;
}
