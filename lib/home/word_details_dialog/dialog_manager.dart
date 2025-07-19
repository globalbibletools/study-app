import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';

class WordDetailsDialogManager extends ChangeNotifier {
  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();
  final _glossService = getIt<GlossService>();

  WordDetails? wordDetails;
  String? grammarExpansion;

  Future<void> init(Locale locale, int wordId) async {
    wordDetails = await _getWordDetails(locale, wordId);
    notifyListeners();
  }

  Future<WordDetails> _getWordDetails(Locale uiLocale, int wordId) async {
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

  void showGrammar(String grammar) {
    grammarExpansion = _parsePart(grammar);
    notifyListeners();
  }

  /// Parses a single morphological part (e.g., "Prep-l" or "Art").
  ///
  /// It handles both simple codes and compound codes separated by hyphens.
  /// If a code is not found in the [morphologyCodes] map, it is returned as is.
  String _parsePart(String grammar) {
    final output = StringBuffer();

    final parts = grammar.split('-');
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final expanded = _morphologyCodes[part] ?? part;
      if (i == 0) {
        output.write(expanded[0].toUpperCase());
        output.write(expanded.substring(1));
      } else if (i == 1) {
        output.write(': ');
        output.write(expanded);
      } else if (i > 1) {
        output.write(', ');
        output.write(expanded);
      }
    }

    return output.toString();
  }

  void hideGrammar() {
    grammarExpansion = null;
    notifyListeners();
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

/// A map of morphology codes and their corresponding descriptions.
const Map<String, String> _morphologyCodes = {
  '1P': 'first person plural',
  '1S': 'first person singular',
  '1cp': 'first-person common-gender plural',
  '1cp2': 'first-person common-gender plural (suffix-type 2)',
  '1cpe': 'first-person common-gender plural, emphatic',
  '1cs': 'first-person common-gender singular',
  '1cs2': 'first-person common-gender singular (suffix-type 2)',
  '1cse': 'first-person common-gender singular, emphatic',
  '2P': 'second person plural',
  '2S': 'second person singular',
  '2fp': 'second-person feminine plural',
  '2fs': 'second-person feminine singular',
  '2fs2': 'second-person feminine singular (suffix-type 2)',
  '2mp': 'second-person masculine plural',
  '2mpe': 'second-person masculine plural, emphatic',
  '2ms': 'second-person masculine singular',
  '2mse': 'second-person masculine singular, emphatic',
  '2mse2': 'second-person masculine singular, emphatic (suffix-type 2)',
  '3P': 'third person plural',
  '3S': 'third person singular',
  '3cp': 'third-person common-gender plural',
  '3fp': 'third-person feminine plural',
  '3fs': 'third-person feminine singular',
  '3fse': 'third-person feminine singular, emphatic',
  '3mp': 'third-person masculine plural',
  '3ms': 'third-person masculine singular',
  '3mse': 'third-person masculine singular, emphatic',
  'A1P': 'accusative first-person plural',
  'A1S': 'accusative first-person singular',
  'A2P': 'accusative second-person plural',
  'A2S': 'accusative second-person singular',
  'AF1P': 'accusative feminine first-person plural',
  'AF1S': 'accusative feminine first-person singular',
  'AF2P': 'accusative feminine second-person plural',
  'AF2S': 'accusative feminine second-person singular',
  'AF3P': 'accusative feminine third-person plural',
  'AF3S': 'accusative feminine third-person singular',
  'AFP': 'accusative feminine plural',
  'AFS': 'accusative feminine singular',
  'AIA': 'aorist indicative active',
  'AIM': 'aorist indicative middle',
  'AIP': 'aorist indicative passive',
  'AM1P': 'accusative masculine first-person plural',
  'AM1S': 'accusative masculine first-person singular',
  'AM2P': 'accusative masculine second-person plural',
  'AM2S': 'accusative masculine second-person singular',
  'AM3P': 'accusative masculine third-person plural',
  'AM3S': 'accusative masculine third-person singular',
  'AMA': 'aorist imperative active',
  'AMM': 'aorist imperative middle',
  'AMP': 'aorist imperative passive',
  'AMS': 'accusative masculine singular',
  'AN1P': 'accusative neuter first-person plural',
  'AN1S': 'accusative neuter first-person singular',
  'AN2P': 'accusative neuter second-person plural',
  'AN2S': 'accusative neuter second-person singular',
  'AN3P': 'accusative neuter third-person plural',
  'AN3S': 'accusative neuter third-person singular',
  'ANA': 'aorist infinitive active',
  'ANM': 'aorist infinitive middle',
  'ANM/P': 'aorist infinitive middle/passive',
  'ANP': 'aorist infinitive passive',
  'ANS': 'accusative neuter singular',
  'AOA': 'aorist optative active',
  'AOM': 'aorist optative middle',
  'AOP': 'aorist optative passive',
  'APA': 'aorist participle active',
  'APM': 'aorist participle middle',
  'APM/P': 'aorist participle middle/passive',
  'APP': 'aorist participle passive',
  'ASA': 'aorist subjunctive active',
  'ASM': 'aorist subjunctive middle',
  'ASP': 'aorist subjunctive passive',
  'Adj': 'adjective',
  'Adv': 'adverb',
  'Art': 'article',
  'C': 'common gender',
  'Conj': 'conjunction',
  'ConjImperf': 'conjunctive (waw-) imperfect',
  'ConjImperf.Cohort': 'conjunctive imperfect cohortative',
  'ConjImperf.Jus': 'conjunctive imperfect jussive',
  'ConjImperf.h': 'conjunctive imperfect with paragogic ה',
  'ConjPerf': 'conjunctive (waw-) perfect',
  'ConsecImperf': 'consecutive imperfect',
  'D1P': 'dative first-person plural',
  'D1S': 'dative first-person singular',
  'D2P': 'dative second-person plural',
  'D2S': 'dative second-person singular',
  'DF1P': 'dative feminine first-person plural',
  'DF1S': 'dative feminine first-person singular',
  'DF2P': 'dative feminine second-person plural',
  'DF2S': 'dative feminine second-person singular',
  'DF3P': 'dative feminine third-person plural',
  'DF3S': 'dative feminine third-person singular',
  'DFP': 'dative feminine plural',
  'DFS': 'dative feminine singular',
  'DM1P': 'dative masculine first-person plural',
  'DM1S': 'dative masculine first-person singular',
  'DM2P': 'dative masculine second-person plural',
  'DM2S': 'dative masculine second-person singular',
  'DM3P': 'dative masculine third-person plural',
  'DM3S': 'dative masculine third-person singular',
  'DMP': 'dative masculine plural',
  'DMS': 'dative masculine singular',
  'DN1P': 'dative neuter first-person plural',
  'DN1S': 'dative neuter first-person singular',
  'DN3P': 'dative neuter third-person plural',
  'DN3S': 'dative neuter third-person singular',
  'DNP': 'dative neuter plural',
  'DNS': 'dative neuter singular',
  'DPro': 'demonstrative pronoun',
  'DirObj': 'direct-object marker (אֶת)',
  'DirObjM': 'direct-object marker with maqqēf',
  'FI': 'future indicative',
  'FIA': 'future indicative active',
  'FIM': 'future indicative middle',
  'FIM/P': 'future indicative middle/passive',
  'FIP': 'future indicative passive',
  'FNA': 'future infinitive active',
  'FNM': 'future infinitive middle',
  'FPA': 'future participle active',
  'FPM': 'future participle middle',
  'FPP': 'future participle passive',
  'G1P': 'genitive first-person plural',
  'G1S': 'genitive first-person singular',
  'G2P': 'genitive second-person plural',
  'G2S': 'genitive second-person singular',
  'GF1P': 'genitive feminine first-person plural',
  'GF1S': 'genitive feminine first-person singular',
  'GF2P': 'genitive feminine second-person plural',
  'GF2S': 'genitive feminine second-person singular',
  'GF3P': 'genitive feminine third-person plural',
  'GF3S': 'genitive feminine third-person singular',
  'GFP': 'genitive feminine plural',
  'GFS': 'genitive feminine singular',
  'GM1S': 'genitive masculine first-person singular',
  'GM2S': 'genitive masculine second-person singular',
  'GM3P': 'genitive masculine third-person plural',
  'GM3S': 'genitive masculine third-person singular',
  'GMP': 'genitive masculine plural',
  'GMS': 'genitive masculine singular',
  'GN1P': 'genitive neuter first-person plural',
  'GN3P': 'genitive neuter third-person plural',
  'GN3S': 'genitive neuter third-person singular',
  'GNP': 'genitive neuter plural',
  'GNS': 'genitive neuter singular',
  'Heb': 'Hebrew',
  'Hifil': 'Hifil stem (causative active)',
  'Hitpael': 'Hitpael stem (intensive reflexive)',
  'Hofal': 'Hofal stem (causative passive)',
  'I': 'interjection',
  'IIA': 'imperfect indicative active',
  'IIM': 'imperfect indicative middle',
  'IIM/P': 'imperfect indicative middle/passive',
  'IIP': 'imperfect indicative passive',
  'IPro': 'interrogative or indefinite pronoun',
  'Imp': 'imperative',
  'Imperf': 'imperfect',
  'Imperf.Cohort': 'imperfect cohortative',
  'Imperf.Jus': 'imperfect jussive',
  'Imperf.h': 'imperfect with paragogic ה',
  'Indec': 'indeclinable',
  'Inf': 'infinitive',
  'InfAbs': 'infinitive absolute',
  'IntPrtcl': 'interrogative particle',
  'Interjection': 'interjection',
  'Interrog': 'interrogative',
  'LIA': 'pluperfect indicative active',
  'LIM': 'pluperfect indicative middle',
  'LIM/P': 'pluperfect indicative middle/passive',
  'M': 'masculine',
  'N': 'noun',
  'N1P': 'nominative first-person plural',
  'N1S': 'nominative first-person singular',
  'N2P': 'nominative second-person plural',
  'N2S': 'nominative second-person singular',
  'NF1P': 'nominative feminine first-person plural',
  'NF1S': 'nominative feminine first-person singular',
  'NF2P': 'nominative feminine second-person plural',
  'NF3S': 'nominative feminine third-person singular',
  'NFP': 'nominative feminine plural',
  'NFS': 'nominative feminine singular',
  'NM1P': 'nominative masculine first-person plural',
  'NM1S': 'nominative masculine first-person singular',
  'NM2P': 'nominative masculine second-person plural',
  'NM2S': 'nominative masculine second-person singular',
  'NM3P': 'nominative masculine third-person plural',
  'NM3S': 'nominative masculine third-person singular',
  'NMP': 'nominative masculine plural',
  'NMS': 'nominative masculine singular',
  'NN1P': 'nominative neuter first-person plural',
  'NN1S': 'nominative neuter first-person singular',
  'NN2P': 'nominative neuter second-person plural',
  'NN2S': 'nominative neuter second-person singular',
  'NN3P': 'nominative neuter third-person plural',
  'NN3S': 'nominative neuter third-person singular',
  'NNP': 'nominative neuter plural',
  'NNS': 'nominative neuter singular',
  'NegPrt': 'negative particle',
  'Nifal': 'Nifal stem (simple passive)',
  'Nithpael': 'Nithpael stem (reflexive intensive passive)',
  'Number': 'number (grammatical count: singular, plural, etc.)',
  'PI': 'present indicative',
  'PIA': 'present indicative active',
  'PIM': 'present indicative middle',
  'PIM/P': 'present indicative middle/passive',
  'PIP': 'present indicative passive',
  'PMA': 'present imperative active',
  'PMM': 'present imperative middle',
  'PMM/P': 'present imperative middle/passive',
  'PMP': 'present imperative passive',
  'PNA': 'present infinitive active',
  'PNM': 'present infinitive middle',
  'PNM/P': 'present infinitive middle/passive',
  'PNP': 'present infinitive passive',
  'POA': 'present optative active',
  'POM/P': 'present optative middle/passive',
  'PPA': 'present participle active',
  'PPM': 'present participle middle',
  'PPM/P': 'present participle middle/passive',
  'PPP': 'present participle passive',
  'PPro': 'personal or possessive pronoun',
  'PSA': 'present subjunctive active',
  'PSM': 'present subjunctive middle',
  'PSM/P': 'present subjunctive middle/passive',
  'Pd': 'participle determined',
  'Perf': 'perfect',
  'Pg': 'paragogic gerundive',
  'Pi': 'passive infinitive',
  'Piel': 'Piel stem (intensive active)',
  'Pn': 'proper noun',
  'Poel': 'Poel stem (emphatic active)',
  'Pr': 'preposition',
  'Prep': 'preposition',
  'Pro': 'Pronoun',
  'Prtcl': 'particle',
  'Prtcpl': 'participle',
  'Pual': 'Pual stem (intensive passive)',
  'Qal': 'Qal stem (simple active)',
  'QalPass': 'Qal passive',
  'QalPassPrtcpl': 'Qal passive participle',
  'RIA': 'future indicative active',
  'RIM': 'future indicative middle',
  'RIM/P': 'future indicative middle/passive',
  'RIP': 'future indicative passive',
  'RMA': 'future imperative active',
  'RMM/P': 'future imperative middle/passive',
  'RNA': 'future infinitive active',
  'RNM/P': 'future infinitive middle/passive',
  'RPA': 'future participle active',
  'RPM': 'future participle middle',
  'RPM/P': 'future participle middle/passive',
  'RPP': 'future participle passive',
  'RSA': 'future subjunctive active',
  'RecPro': 'reciprocal pronoun',
  'RefPro': 'reflexive pronoun',
  'RelPro': 'relative pronoun',
  'S': 'singular',
  'Tiftl': 'Tif‘al stem (rare reflexive/causative)',
  'V': 'Verb',
  'VFP': 'vocative feminine plural',
  'VFS': 'vocative feminine singular',
  'VMP': 'vocative masculine plural',
  'VMS': 'vocative masculine singular',
  'VNP': 'vocative neuter plural',
  'VNS': 'vocative neuter singular',
  'b': 'prefix beth ("in, with, by")',
  'cd': 'common dual absolute',
  'cdc': 'common dual construct',
  'cp': 'common plural absolute',
  'cpc': 'common plural construct',
  'cs': 'common singular absolute',
  'csc': 'common singular construct',
  'csd': 'common singular determined',
  'fb': 'feminine dual absolute',
  'fc': 'feminine dual construct',
  'fd': 'feminine dual determined',
  'fdc': 'feminine dual construct (variant)',
  'fp': 'feminine plural absolute',
  'fpc': 'feminine plural construct',
  'fpd': 'feminine plural determined',
  'fs': 'feminine singular absolute',
  'fsc': 'feminine singular construct',
  'fsd': 'feminine singular determined',
  'gms': 'gentilic masculine singular',
  'k': 'prefix kaf ("like, as")',
  'l': 'prefix lamed ("to, for")',
  'm': 'masculine',
  'mb': 'masculine dual absolute',
  'md': 'masculine dual absolute',
  'mdc': 'masculine dual construct',
  'mdd': 'masculine dual determined',
  'mp': 'masculine plural absolute',
  'mpc': 'masculine plural construct',
  'mpd': 'masculine plural determined',
  'ms': 'masculine singular absolute',
  'msc': 'masculine singular construct',
  'msd': 'masculine singular determined',
  'ofpc': 'ordinal feminine plural construct',
  'ofs': 'ordinal feminine singular',
  'ofsc': 'ordinal feminine singular construct',
  'ofsd': 'ordinal feminine singular determined',
  'omp': 'ordinal masculine plural',
  'oms': 'ordinal masculine singular',
  'omsd': 'ordinal masculine singular determined',
  'proper': 'proper name',
  'r': 'relative particle',
  'w': 'prefix waw ("and")',
};
