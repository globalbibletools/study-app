import 'package:flutter/widgets.dart';
import 'package:studyapp/app_state.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class HomeManager {
  final currentBookNotifier = ValueNotifier<String>('');
  final currentChapterNotifier = ValueNotifier<int>(1);
  final chapterCountNotifier = ValueNotifier<int?>(null);
  final pageJumpNotifier = ValueNotifier<int?>(null);
  final pageDirectionNotifier = ValueNotifier<TextDirection>(TextDirection.rtl);

  final _glossService = getIt<GlossService>();
  final _settings = getIt<UserSettings>();
  int _currentBookId = 1;

  void Function(Locale)? onGlossDownloadNeeded;

  static const _lastOldTestamentBookId = 39;
  bool isRtl(int bookId) => bookId <= _lastOldTestamentBookId;

  double get baseFontSize => _settings.baseFontSize;

  // The total number of chapters in the Bible
  static const int totalChapters = 1189;

  Future<void> init(BuildContext context) async {
    final (bookId, chapter) = _settings.currentBookChapter;
    _updateUiForBook(context, bookId, chapter);
  }

  void _updateUiForBook(BuildContext context, int bookId, int chapter) {
    _currentBookId = bookId;
    currentBookNotifier.value = _bookNameFromId(context, bookId);
    currentChapterNotifier.value = chapter;
    pageDirectionNotifier.value =
        isRtl(bookId) ? TextDirection.rtl : TextDirection.ltr;
  }

  // Called from the UI when a page is swiped to
  void onPageChanged(BuildContext context, int pageIndex) {
    final (bookId, chapter) = bookAndChapterForPageIndex(pageIndex);
    _updateUiForBook(context, bookId, chapter);
    _settings.setCurrentBookChapter(bookId, chapter);
  }

  void showChapterChooser() {
    final numberOfChapters = _bookIdToChapterCountMap[_currentBookId];
    chapterCountNotifier.value = numberOfChapters;
  }

  Future<void> onBookSelected(BuildContext context, int? bookId) async {
    if (bookId == null) return;
    const currentChapter = 1;
    _updateUiForBook(context, bookId, currentChapter);
    await _settings.setCurrentBookChapter(bookId, currentChapter);
    pageJumpNotifier.value = pageIndexForBookAndChapter(bookId, currentChapter);
  }

  Future<void> onChapterSelected(int? chapter) async {
    chapterCountNotifier.value = null;
    if (chapter == null) return;
    currentChapterNotifier.value = chapter;
    await _settings.setCurrentBookChapter(_currentBookId, chapter);
    pageJumpNotifier.value = pageIndexForBookAndChapter(
      _currentBookId,
      chapter,
    );
  }

  int pageIndexForBookAndChapter(int bookId, int chapter) {
    int index = 0;
    // Sum chapters of all preceding books
    for (int i = 1; i < bookId; i++) {
      index += _bookIdToChapterCountMap[i]!;
    }
    index += chapter - 1;
    return index;
  }

  (int bookId, int chapter) bookAndChapterForPageIndex(int index) {
    int pageIndex = index % totalChapters;
    int currentBookId = 1;
    int currentChapter = 1;
    int remainingIndex = pageIndex;

    for (final entry in _bookIdToChapterCountMap.entries) {
      if (remainingIndex < entry.value) {
        currentBookId = entry.key;
        currentChapter = remainingIndex + 1;
        break;
      }
      remainingIndex -= entry.value;
    }
    return (currentBookId, currentChapter);
  }

  (int, int) getInitialBookAndChapter() {
    return _settings.currentBookChapter;
  }

  Future<void> saveFontScale(double scale) async {
    await _settings.setFontScale(scale);
  }

  double getFontScale() {
    return _settings.fontScale;
  }

  Future<String?> getPopupTextForId(Locale uiLocale, int wordId) async {
    return _glossService.glossForId(
      locale: uiLocale,
      wordId: wordId,
      onDatabaseMissing: onGlossDownloadNeeded,
    );
  }

  // Called from the UI when user agrees to download.
  Future<void> downloadGlosses(Locale locale) async {
    await _glossService.downloadGlosses(locale);
  }

  // Called from the UI when user wants to use English instead of downloading.
  Future<void> setLanguageToEnglish(Locale originalLocale) async {
    await _settings.setLocale('en');
    getIt<AppState>().init();
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
