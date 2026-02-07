// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get theme => 'Theme';

  @override
  String get systemDefault => 'System Default';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get about => 'About';

  @override
  String get appName => 'Global Bible Tools';

  @override
  String get sourceCode => 'App source code';

  @override
  String get emailCopied => 'Email copied';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get currentLanguage => 'English';

  @override
  String get textSize => 'Text size';

  @override
  String get hebrewGreekTextSize => 'Hebrew/Greek';

  @override
  String get secondPanelTextSize => 'Second panel';

  @override
  String get lexiconTextSize => 'Lexicon';

  @override
  String get downloadResourcesMessage =>
      'To use this language, we need to download additional resources.';

  @override
  String get useEnglish => 'Use English';

  @override
  String get download => 'Download';

  @override
  String get cancel => 'Cancel';

  @override
  String get downloadComplete => 'Download complete.';

  @override
  String get downloadFailed =>
      'Download failed. Please check your internet connection and try again.';

  @override
  String get nextChapter => 'Next chapter';

  @override
  String get root => 'Root';

  @override
  String get exact => 'Exact';

  @override
  String get search => 'Search';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String get repeatNone => 'None';

  @override
  String get repeatVerse => 'Repeat verse';

  @override
  String get repeatChapter => 'Repeat chapter';

  @override
  String get audioRecordingSource => 'Recording Source';

  @override
  String get sourceHEB => 'Shmueloff';

  @override
  String get sourceRDB => 'Dan Beeri';

  @override
  String get downloadAudio => 'Download Audio';

  @override
  String audioNotDownloaded(String book, int chapter) {
    return 'Audio for $book $chapter is not on your device.';
  }

  @override
  String get audioNotAvailable => 'Audio is not available for this chapter.';

  @override
  String get verseCopied => 'Verse copied to clipboard';

  @override
  String get downloads => 'Downloads';

  @override
  String get audio => 'Audio';

  @override
  String get bibles => 'Bibles';

  @override
  String get lexicons => 'Lexicons';

  @override
  String get oldTestament => 'Old Testament';

  @override
  String deleteAudioConfirmation(String book) {
    return 'Delete all audio for $book?';
  }

  @override
  String get delete => 'Delete';

  @override
  String downloadAudioConfirmation(int count, String book) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count missing chapters for $book?',
      one: 'Download 1 missing chapter for $book?',
    );
    return '$_temp0';
  }

  @override
  String get bookGenesis => 'Genesis';

  @override
  String get bookExodus => 'Exodus';

  @override
  String get bookLeviticus => 'Leviticus';

  @override
  String get bookNumbers => 'Numbers';

  @override
  String get bookDeuteronomy => 'Deuteronomy';

  @override
  String get bookJoshua => 'Joshua';

  @override
  String get bookJudges => 'Judges';

  @override
  String get bookRuth => 'Ruth';

  @override
  String get book1Samuel => '1 Samuel';

  @override
  String get book2Samuel => '2 Samuel';

  @override
  String get book1Kings => '1 Kings';

  @override
  String get book2Kings => '2 Kings';

  @override
  String get book1Chronicles => '1 Chronicles';

  @override
  String get book2Chronicles => '2 Chronicles';

  @override
  String get bookEzra => 'Ezra';

  @override
  String get bookNehemiah => 'Nehemiah';

  @override
  String get bookEsther => 'Esther';

  @override
  String get bookJob => 'Job';

  @override
  String get bookPsalms => 'Psalms';

  @override
  String get bookProverbs => 'Proverbs';

  @override
  String get bookEcclesiastes => 'Ecclesiastes';

  @override
  String get bookSongOfSolomon => 'Song of Solomon';

  @override
  String get bookIsaiah => 'Isaiah';

  @override
  String get bookJeremiah => 'Jeremiah';

  @override
  String get bookLamentations => 'Lamentations';

  @override
  String get bookEzekiel => 'Ezekiel';

  @override
  String get bookDaniel => 'Daniel';

  @override
  String get bookHosea => 'Hosea';

  @override
  String get bookJoel => 'Joel';

  @override
  String get bookAmos => 'Amos';

  @override
  String get bookObadiah => 'Obadiah';

  @override
  String get bookJonah => 'Jonah';

  @override
  String get bookMicah => 'Micah';

  @override
  String get bookNahum => 'Nahum';

  @override
  String get bookHabakkuk => 'Habakkuk';

  @override
  String get bookZephaniah => 'Zephaniah';

  @override
  String get bookHaggai => 'Haggai';

  @override
  String get bookZechariah => 'Zechariah';

  @override
  String get bookMalachi => 'Malachi';

  @override
  String get bookMatthew => 'Matthew';

  @override
  String get bookMark => 'Mark';

  @override
  String get bookLuke => 'Luke';

  @override
  String get bookJohn => 'John';

  @override
  String get bookActs => 'Acts';

  @override
  String get bookRomans => 'Romans';

  @override
  String get book1Corinthians => '1 Corinthians';

  @override
  String get book2Corinthians => '2 Corinthians';

  @override
  String get bookGalatians => 'Galatians';

  @override
  String get bookEphesians => 'Ephesians';

  @override
  String get bookPhilippians => 'Philippians';

  @override
  String get bookColossians => 'Colossians';

  @override
  String get book1Thessalonians => '1 Thessalonians';

  @override
  String get book2Thessalonians => '2 Thessalonians';

  @override
  String get book1Timothy => '1 Timothy';

  @override
  String get book2Timothy => '2 Timothy';

  @override
  String get bookTitus => 'Titus';

  @override
  String get bookPhilemon => 'Philemon';

  @override
  String get bookHebrews => 'Hebrews';

  @override
  String get bookJames => 'James';

  @override
  String get book1Peter => '1 Peter';

  @override
  String get book2Peter => '2 Peter';

  @override
  String get book1John => '1 John';

  @override
  String get book2John => '2 John';

  @override
  String get book3John => '3 John';

  @override
  String get bookJude => 'Jude';

  @override
  String get bookRevelation => 'Revelation';
}
