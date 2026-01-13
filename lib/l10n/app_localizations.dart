import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// The title of the About screen
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Displayed on the About page
  ///
  /// In en, this message translates to:
  /// **'Global Bible Tools'**
  String get appName;

  /// Button text for the link to the source code on GitHub
  ///
  /// In en, this message translates to:
  /// **'App source code'**
  String get sourceCode;

  /// Message shown after email button clicked
  ///
  /// In en, this message translates to:
  /// **'Email copied'**
  String get emailCopied;

  /// The title of the Settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Settings menu item to change the app language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// The name of the language for this locale
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get currentLanguage;

  /// Menu item for text size settings
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// Settings option to change the display size of the Hebrew or Greek font
  ///
  /// In en, this message translates to:
  /// **'Hebrew/Greek'**
  String get hebrewGreekTextSize;

  /// Settings option to change the text size in the second panel
  ///
  /// In en, this message translates to:
  /// **'Second panel'**
  String get secondPanelTextSize;

  /// Settings option to change the text size in the Lexicon popup
  ///
  /// In en, this message translates to:
  /// **'Lexicon'**
  String get lexiconTextSize;

  /// Message asking user to download glosses for a specific language.
  ///
  /// In en, this message translates to:
  /// **'To show word meanings in English, the data needs to be downloaded. Would you like to download it now?'**
  String get downloadGlossesMessage;

  /// Label for the dialog button to use English glosses
  ///
  /// In en, this message translates to:
  /// **'Use English'**
  String get useEnglish;

  /// Label for the download button
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// Label for the cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Message shown while glosses are downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading word meanings in English...'**
  String get downloadingGlossesMessage;

  /// Message shown when glosses finish downloading.
  ///
  /// In en, this message translates to:
  /// **'Download complete.'**
  String get downloadComplete;

  /// Message shown when glosses fail to download.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please check your internet connection and try again.'**
  String get downloadFailed;

  /// Tool tip for button that advances to the next chapter in the Bible
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get nextChapter;

  /// The root grammatical form (lemma) of a Hebrew or Greek word
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get root;

  /// The exact grammatical form of a Hebrew or Greek word
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get exact;

  /// The title of the Search screen
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// The message to display when returning the number of results for a search. This should properly handle any possible number for a given language: 'No results', '1 result', '27 results'
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No results} =1{1 result} other{{count} results}}'**
  String resultsCount(int count);

  /// Audio setting: Repeat node
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get repeatNone;

  /// Audio setting: Repeat verse
  ///
  /// In en, this message translates to:
  /// **'Repeat verse'**
  String get repeatVerse;

  /// Audio setting: Repeat chapter
  ///
  /// In en, this message translates to:
  /// **'Repeat chapter'**
  String get repeatChapter;

  /// Audio settings: Recording source
  ///
  /// In en, this message translates to:
  /// **'Recording Source'**
  String get audioRecordingSource;

  /// Audio recording source setting: Abraham Shmueloff
  ///
  /// In en, this message translates to:
  /// **'Shmueloff'**
  String get sourceHEB;

  /// Audio recording source setting: Rabbi Dan Beeri
  ///
  /// In en, this message translates to:
  /// **'Dan Beeri'**
  String get sourceRDB;

  /// Title of the download audio dialog
  ///
  /// In en, this message translates to:
  /// **'Download Audio'**
  String get downloadAudio;

  /// Message shown when audio is missing
  ///
  /// In en, this message translates to:
  /// **'Audio for {book} {chapter} is not on your device.'**
  String audioNotDownloaded(String book, int chapter);

  /// Message shown when the user tries to play audio for a chapter that does not exist on the server.
  ///
  /// In en, this message translates to:
  /// **'Audio is not available for this chapter.'**
  String get audioNotAvailable;

  /// Snackbar message when a verse is copied
  ///
  /// In en, this message translates to:
  /// **'Verse copied to clipboard'**
  String get verseCopied;

  /// The name of the first book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Genesis'**
  String get bookGenesis;

  /// The name of the second book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Exodus'**
  String get bookExodus;

  /// The name of the third book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Leviticus'**
  String get bookLeviticus;

  /// The name of the fourth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get bookNumbers;

  /// The name of the fifth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Deuteronomy'**
  String get bookDeuteronomy;

  /// The name of the sixth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Joshua'**
  String get bookJoshua;

  /// The name of the seventh book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Judges'**
  String get bookJudges;

  /// The name of the eighth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Ruth'**
  String get bookRuth;

  /// The name of the ninth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'1 Samuel'**
  String get book1Samuel;

  /// The name of the tenth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'2 Samuel'**
  String get book2Samuel;

  /// The name of the eleventh book of the Bible
  ///
  /// In en, this message translates to:
  /// **'1 Kings'**
  String get book1Kings;

  /// The name of the twelfth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'2 Kings'**
  String get book2Kings;

  /// The name of the thirteenth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'1 Chronicles'**
  String get book1Chronicles;

  /// The name of the fourteenth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'2 Chronicles'**
  String get book2Chronicles;

  /// The name of the fifteenth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Ezra'**
  String get bookEzra;

  /// The name of the sixteenth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Nehemiah'**
  String get bookNehemiah;

  /// The name of the seventeenth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Esther'**
  String get bookEsther;

  /// The name of the eighteenth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get bookJob;

  /// The name of the nineteenth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Psalms'**
  String get bookPsalms;

  /// The name of the twentieth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Proverbs'**
  String get bookProverbs;

  /// The name of the twenty-first book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Ecclesiastes'**
  String get bookEcclesiastes;

  /// The name of the twenty-second book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Song of Solomon'**
  String get bookSongOfSolomon;

  /// The name of the twenty-third book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Isaiah'**
  String get bookIsaiah;

  /// The name of the twenty-fourth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Jeremiah'**
  String get bookJeremiah;

  /// The name of the twenty-fifth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Lamentations'**
  String get bookLamentations;

  /// The name of the twenty-sixth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Ezekiel'**
  String get bookEzekiel;

  /// The name of the twenty-seventh book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Daniel'**
  String get bookDaniel;

  /// The name of the twenty-eighth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Hosea'**
  String get bookHosea;

  /// The name of the twenty-ninth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Joel'**
  String get bookJoel;

  /// The name of the thirtieth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Amos'**
  String get bookAmos;

  /// The name of the thirty-first book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Obadiah'**
  String get bookObadiah;

  /// The name of the thirty-second book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Jonah'**
  String get bookJonah;

  /// The name of the thirty-third book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Micah'**
  String get bookMicah;

  /// The name of the thirty-fourth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Nahum'**
  String get bookNahum;

  /// The name of the thirty-fifth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Habakkuk'**
  String get bookHabakkuk;

  /// The name of the thirty-sixth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Zephaniah'**
  String get bookZephaniah;

  /// The name of the thirty-seventh book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Haggai'**
  String get bookHaggai;

  /// The name of the thirty-eighth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Zechariah'**
  String get bookZechariah;

  /// The name of the thirty-ninth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Malachi'**
  String get bookMalachi;

  /// The name of the fortieth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Matthew'**
  String get bookMatthew;

  /// The name of the forty-first book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get bookMark;

  /// The name of the forty-second book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Luke'**
  String get bookLuke;

  /// The name of the forty-third book of the Bible
  ///
  /// In en, this message translates to:
  /// **'John'**
  String get bookJohn;

  /// The name of the forty-fourth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Acts'**
  String get bookActs;

  /// The name of the forty-fifth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Romans'**
  String get bookRomans;

  /// The name of the forty-sixth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'1 Corinthians'**
  String get book1Corinthians;

  /// The name of the forty-seventh book of the Bible
  ///
  /// In en, this message translates to:
  /// **'2 Corinthians'**
  String get book2Corinthians;

  /// The name of the forty-eighth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Galatians'**
  String get bookGalatians;

  /// The name of the forty-ninth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Ephesians'**
  String get bookEphesians;

  /// The name of the fiftieth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Philippians'**
  String get bookPhilippians;

  /// The name of the fifty-first book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Colossians'**
  String get bookColossians;

  /// The name of the fifty-second book of the Bible
  ///
  /// In en, this message translates to:
  /// **'1 Thessalonians'**
  String get book1Thessalonians;

  /// The name of the fifty-third book of the Bible
  ///
  /// In en, this message translates to:
  /// **'2 Thessalonians'**
  String get book2Thessalonians;

  /// The name of the fifty-fourth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'1 Timothy'**
  String get book1Timothy;

  /// The name of the fifty-fifth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'2 Timothy'**
  String get book2Timothy;

  /// The name of the fifty-sixth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Titus'**
  String get bookTitus;

  /// The name of the fifty-seventh book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Philemon'**
  String get bookPhilemon;

  /// The name of the fifty-eighth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Hebrews'**
  String get bookHebrews;

  /// The name of the fifty-ninth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'James'**
  String get bookJames;

  /// The name of the sixtieth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'1 Peter'**
  String get book1Peter;

  /// The name of the sixty-first book of the Bible
  ///
  /// In en, this message translates to:
  /// **'2 Peter'**
  String get book2Peter;

  /// The name of the sixty-second book of the Bible
  ///
  /// In en, this message translates to:
  /// **'1 John'**
  String get book1John;

  /// The name of the sixty-third book of the Bible
  ///
  /// In en, this message translates to:
  /// **'2 John'**
  String get book2John;

  /// The name of the sixty-fourth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'3 John'**
  String get book3John;

  /// The name of the sixty-fifth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Jude'**
  String get bookJude;

  /// The name of the sixty-sixth book of the Bible
  ///
  /// In en, this message translates to:
  /// **'Revelation'**
  String get bookRevelation;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
