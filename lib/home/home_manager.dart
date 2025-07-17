import 'package:flutter/widgets.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/common/word.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class HomeManager {
  final currentBookNotifier = ValueNotifier<String>('');
  final currentChapterNotifier = ValueNotifier<int>(1);
  final chapterCountNotifier = ValueNotifier<int?>(null);
  final textNotifier = ValueNotifier<List<HebrewGreekWord>>([]);

  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();
  // final _englishGlossDb = getIt<EnglishDatabase>();
  final _glossService = getIt<GlossService>();
  final _settings = getIt<UserSettings>();
  int _currentBookId = 1;

  void Function()? onTextUpdated;
  void Function(Locale)? onGlossDownloadNeeded;

  static const _lastOldTestamentBookId = 39;
  bool get currentChapterIsRtl => _currentBookId <= _lastOldTestamentBookId;

  Future<void> init(BuildContext context) async {
    final (bookId, chapter) = _settings.currentBookChapter;
    _updateCurrentBookName(context, bookId);
    currentChapterNotifier.value = chapter;
    await _updateText();
    // await _initLocalizedGlosses();
  }

  void _updateCurrentBookName(BuildContext context, int? bookId) {
    _currentBookId = bookId ?? 1;
    currentBookNotifier.value = _bookNameFromId(context, _currentBookId);
  }

  Future<void> _updateText() async {
    final chapter = currentChapterNotifier.value;
    textNotifier.value = await _hebrewGreekDb.getChapter(
      _currentBookId,
      chapter,
    );
    onTextUpdated?.call();
  }

  // Future<void> _initLocalizedGlosses() async {
  //   final languageCode = _settings.locale?.languageCode;
  //   if (languageCode == null || languageCode == 'en') {
  //     return;
  //   }
  //   log('Initializing localized database');
  //   await _glossService.initDb(languageCode);
  // }

  void showChapterChooser() {
    final numberOfChapters = _bookIdToChapterCountMap[_currentBookId];
    chapterCountNotifier.value = numberOfChapters;
  }

  Future<void> onBookSelected(BuildContext context, int? bookId) async {
    if (bookId == null) {
      return;
    }
    _updateCurrentBookName(context, bookId);
    final currentChapter = 1;
    currentChapterNotifier.value = currentChapter;
    await _updateText();
    await _settings.setCurrentBookChapter(bookId, currentChapter);
  }

  Future<void> onChapterSelected(int? chapter) async {
    chapterCountNotifier.value = null;
    if (chapter == null) {
      return;
    }
    currentChapterNotifier.value = chapter;
    await _updateText();
    await _settings.setCurrentBookChapter(_currentBookId, chapter);
  }

  Future<void> saveFontScale(double scale) async {
    await _settings.setFontScale(scale);
  }

  double getFontScale() {
    return _settings.fontScale;
  }

  bool isDownloadableLanguage(Locale locale) {
    if (locale.languageCode == 'en') return false;
    return AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == locale.languageCode,
    );
  }

  Future<String?> getPopupTextForId(Locale uiLocale, int wordId) async {
    return _glossService.glossForId(
      locale: uiLocale,
      wordId: wordId,
      onDatabaseMissing: onGlossDownloadNeeded,
    );

    // final glossLocale = _settings.locale ?? uiLocale;

    // if (!isDownloadableLanguage(glossLocale)) {
    //   return await _getEnglishGloss(wordId);
    // }

    // final langCode = glossLocale.languageCode;
    // final dbExists = await _glossService.glossDbExists(langCode);
    // if (dbExists) {
    //   final localizedGloss = await _glossService.getGloss(langCode, wordId);
    //   return localizedGloss ?? await _getEnglishGloss(wordId);
    // } else {
    //   onGlossDownloadNeeded?.call(Locale(langCode));
    //   return await _getEnglishGloss(wordId);
    // }
  }

  // Future<String?> _getEnglishGloss(int wordId) async {
  //   return await _englishGlossDb.getGloss(wordId);
  // }

  // Called from the UI when user agrees to download.
  Future<void> downloadGlosses(Locale locale) async {
    await _glossService.downloadGlosses(locale);
    // try {
    //   await _glossService.downloadAndInstallGlossDb(locale.languageCode);
    //   await _glossService.initDb(locale.languageCode);
    // } catch (e) {
    //   log('Gloss download failed for ${locale.languageCode}: $e');
    //   rethrow;
    // }
  }

  // Called from the UI when user wants to use English instead of downloading.
  Future<void> setLanguageToEnglish(Locale originalLocale) async {
    await _settings.setLocale('en');
    getIt<AppState>().init();
  }

  String expandGrammar(String grammarAbbreviation) {
    final testString = 'Prep-l | Interrog | Prep-b, Art | Adj-fs';
    final result = _parseMorphologyString(testString);
    print(result);
    return result;
    // final majorParts = grammarAbbreviation.split('|-');
    // for (final part in majorParts) {
    //   final trimmed = part.trim();
    //   final expanded = _morphologyCodes[trimmed] ?? trimmed;
    //   print('"$expanded"');
    // }
    // return majorParts.first;
  }

  /// Parses a complex morphological string and substitutes the codes.
  ///
  /// The string is expected to be in a format where different interpretations are
  /// separated by " | " and different grammatical parts within an interpretation
  /// are separated by ", ".
  ///
  /// For example: "Prep-l | Interrog | Prep-b, Art | Adj-fs"
  ///
  /// @param input The morphological string to parse.
  /// @return A human-readable string with the codes substituted.
  String _parseMorphologyString(String input) {
    if (input.isEmpty) {
      return '';
    }

    // 1. Split the string by " | " to get the main segments (interpretations).
    return input
        .split('|')
        .map((segment) {
          // 2. For each segment, split by ", " to get the individual parts.
          return segment
              .trim()
              .split(',')
              // 3. For each part, parse it using our helper function.
              .map((part) {
                return _parsePart(part.trim());
              })
              // 4. Join the parsed parts back together with a comma and space.
              .join(', ');
        })
        // 5. Join the fully parsed segments back together with the pipe separator.
        .join(' followed by ');
  }

  /// Parses a single morphological part (e.g., "Prep-l" or "Art").
  ///
  /// It handles both simple codes and compound codes separated by a hyphen.
  /// If a code is not found in the [morphologyCodes] map, it is returned as is.
  String _parsePart(String part) {
    final subParts = part.split('-');

    if (subParts.length > 1) {
      // This is a compound part, e.g., "Prep-l"
      final baseCode = subParts[0];
      final specifierCode = subParts[1];

      // Look up each sub-part, falling back to the code itself if not found.
      final baseDescription = _morphologyCodes[baseCode] ?? baseCode;
      final specifierDescription =
          _morphologyCodes[specifierCode] ?? specifierCode;

      return '$baseDescription, $specifierDescription';
    } else {
      // This is a simple part, e.g., "Interrog"
      return _morphologyCodes[part] ?? part;
    }
  }
}

String _bookNameFromId(BuildContext context, int bookId) {
  switch (bookId) {
    case 1:
      return AppLocalizations.of(context)!.bookGenesis;
    case 2:
      return AppLocalizations.of(context)!.bookExodus;
    case 3:
      return AppLocalizations.of(context)!.bookLeviticus;
    case 4:
      return AppLocalizations.of(context)!.bookNumbers;
    case 5:
      return AppLocalizations.of(context)!.bookDeuteronomy;
    case 6:
      return AppLocalizations.of(context)!.bookJoshua;
    case 7:
      return AppLocalizations.of(context)!.bookJudges;
    case 8:
      return AppLocalizations.of(context)!.bookRuth;
    case 9:
      return AppLocalizations.of(context)!.book1Samuel;
    case 10:
      return AppLocalizations.of(context)!.book2Samuel;
    case 11:
      return AppLocalizations.of(context)!.book1Kings;
    case 12:
      return AppLocalizations.of(context)!.book2Kings;
    case 13:
      return AppLocalizations.of(context)!.book1Chronicles;
    case 14:
      return AppLocalizations.of(context)!.book2Chronicles;
    case 15:
      return AppLocalizations.of(context)!.bookEzra;
    case 16:
      return AppLocalizations.of(context)!.bookNehemiah;
    case 17:
      return AppLocalizations.of(context)!.bookEsther;
    case 18:
      return AppLocalizations.of(context)!.bookJob;
    case 19:
      return AppLocalizations.of(context)!.bookPsalms;
    case 20:
      return AppLocalizations.of(context)!.bookProverbs;
    case 21:
      return AppLocalizations.of(context)!.bookEcclesiastes;
    case 22:
      return AppLocalizations.of(context)!.bookSongOfSolomon;
    case 23:
      return AppLocalizations.of(context)!.bookIsaiah;
    case 24:
      return AppLocalizations.of(context)!.bookJeremiah;
    case 25:
      return AppLocalizations.of(context)!.bookLamentations;
    case 26:
      return AppLocalizations.of(context)!.bookEzekiel;
    case 27:
      return AppLocalizations.of(context)!.bookDaniel;
    case 28:
      return AppLocalizations.of(context)!.bookHosea;
    case 29:
      return AppLocalizations.of(context)!.bookJoel;
    case 30:
      return AppLocalizations.of(context)!.bookAmos;
    case 31:
      return AppLocalizations.of(context)!.bookObadiah;
    case 32:
      return AppLocalizations.of(context)!.bookJonah;
    case 33:
      return AppLocalizations.of(context)!.bookMicah;
    case 34:
      return AppLocalizations.of(context)!.bookNahum;
    case 35:
      return AppLocalizations.of(context)!.bookHabakkuk;
    case 36:
      return AppLocalizations.of(context)!.bookZephaniah;
    case 37:
      return AppLocalizations.of(context)!.bookHaggai;
    case 38:
      return AppLocalizations.of(context)!.bookZechariah;
    case 39:
      return AppLocalizations.of(context)!.bookMalachi;
    case 40:
      return AppLocalizations.of(context)!.bookMatthew;
    case 41:
      return AppLocalizations.of(context)!.bookMark;
    case 42:
      return AppLocalizations.of(context)!.bookLuke;
    case 43:
      return AppLocalizations.of(context)!.bookJohn;
    case 44:
      return AppLocalizations.of(context)!.bookActs;
    case 45:
      return AppLocalizations.of(context)!.bookRomans;
    case 46:
      return AppLocalizations.of(context)!.book1Corinthians;
    case 47:
      return AppLocalizations.of(context)!.book2Corinthians;
    case 48:
      return AppLocalizations.of(context)!.bookGalatians;
    case 49:
      return AppLocalizations.of(context)!.bookEphesians;
    case 50:
      return AppLocalizations.of(context)!.bookPhilippians;
    case 51:
      return AppLocalizations.of(context)!.bookColossians;
    case 52:
      return AppLocalizations.of(context)!.book1Thessalonians;
    case 53:
      return AppLocalizations.of(context)!.book2Thessalonians;
    case 54:
      return AppLocalizations.of(context)!.book1Timothy;
    case 55:
      return AppLocalizations.of(context)!.book2Timothy;
    case 56:
      return AppLocalizations.of(context)!.bookTitus;
    case 57:
      return AppLocalizations.of(context)!.bookPhilemon;
    case 58:
      return AppLocalizations.of(context)!.bookHebrews;
    case 59:
      return AppLocalizations.of(context)!.bookJames;
    case 60:
      return AppLocalizations.of(context)!.book1Peter;
    case 61:
      return AppLocalizations.of(context)!.book2Peter;
    case 62:
      return AppLocalizations.of(context)!.book1John;
    case 63:
      return AppLocalizations.of(context)!.book2John;
    case 64:
      return AppLocalizations.of(context)!.book3John;
    case 65:
      return AppLocalizations.of(context)!.bookJude;
    case 66:
      return AppLocalizations.of(context)!.bookRevelation;

    default:
      return '';
  }
}

final Map<int, int> _bookIdToChapterCountMap = {
  1: 50, // Genesis
  2: 40, // Exodus
  3: 27, // Leviticus
  4: 36, // Numbers
  5: 34, // Deuteronomy
  6: 24, // Joshua
  7: 21, // Judges
  8: 4, // Ruth
  9: 31, // 1 Samuel
  10: 24, // 2 Samuel
  11: 22, // 1 Kings
  12: 25, // 2 Kings
  13: 29, // 1 Chronicles
  14: 36, // 2 Chronicles
  15: 10, // Ezra
  16: 13, // Nehemiah
  17: 10, // Esther
  18: 42, // Job
  19: 150, // Psalms
  20: 31, // Proverbs
  21: 12, // Ecclesiastes
  22: 8, // Song of Solomon
  23: 66, // Isaiah
  24: 52, // Jeremiah
  25: 5, // Lamentations
  26: 48, // Ezekiel
  27: 12, // Daniel
  28: 14, // Hosea
  29: 3, // Joel
  30: 9, // Amos
  31: 1, // Obadiah
  32: 4, // Jonah
  33: 7, // Micah
  34: 3, // Nahum
  35: 3, // Habakkuk
  36: 3, // Zephaniah
  37: 2, // Haggai
  38: 14, // Zechariah
  39: 4, // Malachi
  40: 28, // Matthew
  41: 16, // Mark
  42: 24, // Luke
  43: 21, // John
  44: 28, // Acts
  45: 16, // Romans
  46: 16, // 1 Corinthians
  47: 13, // 2 Corinthians
  48: 6, // Galatians
  49: 6, // Ephesians
  50: 4, // Philippians
  51: 4, // Colossians
  52: 5, // 1 Thessalonians
  53: 3, // 2 Thessalonians
  54: 6, // 1 Timothy
  55: 4, // 2 Timothy
  56: 3, // Titus
  57: 1, // Philemon
  58: 13, // Hebrews
  59: 5, // James
  60: 5, // 1 Peter
  61: 3, // 2 Peter
  62: 5, // 1 John
  63: 1, // 2 John
  64: 1, // 3 John
  65: 1, // Jude
  66: 22, // Revelation
};

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
  'N': 'nominative',
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
  'Pro': 'pronoun',
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
  'V': 'verb',
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
