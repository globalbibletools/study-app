import 'dart:ui' show TextDirection;

import 'package:flutter/foundation.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/hebrew_greek/hebrew_grammar.dart';
import 'package:gbt/services/hebrew_greek/srgnt_grammar.dart';
import 'package:gbt/services/lexicon/database.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/common/resource_language_text_direction.dart';

class WordDetailsDialogManager extends ChangeNotifier {
  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();
  final _glossService = getIt<GlossService>();
  final _lexiconDb = getIt<LexiconsDatabase>();
  final _settings = getIt<UserSettings>();

  WordDetails? wordDetails;
  List<LexiconMeaning> lexiconMeanings = [];

  Future<void> init(String wordId) async {
    wordDetails = await _getWordDetails(wordId);
    lexiconMeanings = await _lexiconDb.getMeaningsForStrongs(
      wordDetails!.strongsCode,
    );
    notifyListeners();
  }

  Future<WordDetails> _getWordDetails(String wordId) async {
    final word = await _hebrewGreekDb.getWordForId(wordId);
    final gloss = await _glossService.glossForId(wordId: wordId);
    final (strongs, grammar) =
        await _hebrewGreekDb.getStrongsAndGrammar(wordId) ?? ('', '');
    return WordDetails(
      word: word?.text ?? '',
      gloss: gloss?.gloss ?? '',
      glossIsAi: gloss?.isAiGenerated ?? false,
      glossTextDirection:
          gloss?.textDirection.toTextDirection ?? TextDirection.ltr,
      strongsCode: strongs,
      grammar: grammar,
    );
  }

  double get initialFontScale => _settings.wordDetailsFontScale;

  Future<void> saveFontScale(double scale) async {
    await _settings.setWordDetailsFontScale(scale);
    notifyListeners();
  }

  String expandGrammar(String grammar) {
    final code = grammar.trim();
    return parseSrgntGrammar(code) ?? parseHebrewGrammar(code) ?? code;
  }
}

class WordDetails {
  const WordDetails({
    required this.word,
    required this.gloss,
    required this.glossIsAi,
    required this.glossTextDirection,
    required this.strongsCode,
    required this.grammar,
  });

  final String word;
  final String gloss;

  final bool glossIsAi;
  final TextDirection glossTextDirection;

  final String strongsCode;
  final String grammar;

  bool get isRtl => strongsCode.startsWith('H');
}

