// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get theme => 'Thème';

  @override
  String get systemDefault => 'Thème du système';

  @override
  String get lightTheme => 'Clair';

  @override
  String get darkTheme => 'Sombre';

  @override
  String get about => 'À propos';

  @override
  String get appName => 'Outils Bibliques pour le monde';

  @override
  String get sourceCode => 'Code source';

  @override
  String get emailCopied => 'Adresse e-mail copiée';

  @override
  String get settings => 'Paramètres';

  @override
  String get language => 'Langue';

  @override
  String get currentLanguage => 'Français';

  @override
  String get textSize => 'Taille du texte';

  @override
  String get hebrewTextSize => 'Hébreu';

  @override
  String get greekTextSize => 'Grec';

  @override
  String get secondPanelTextSize => 'Texte biblique en français';

  @override
  String get lexiconTextSize => 'Lexique';

  @override
  String get verseLayout => 'Mise en page des versets';

  @override
  String get paragraph => 'Paragraphe';

  @override
  String get versePerLine => 'Un verset par ligne';

  @override
  String get downloadResourcesMessage =>
      'Pour utiliser cette langue, nous devons télécharger des ressources supplémentaires.';

  @override
  String get download => 'Télécharger';

  @override
  String get cancel => 'Annuler';

  @override
  String get downloadComplete => 'Téléchargement terminé.';

  @override
  String get downloadFailed =>
      'Le téléchargement a échoué. Veuillez vérifier votre connexion internet et réessayer.';

  @override
  String get nextChapter => 'Chapitre suivant';

  @override
  String get root => 'Racine';

  @override
  String get exact => 'Exact';

  @override
  String get search => 'Rechercher';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
      zero: 'Aucun résultat',
    );
    return '$_temp0';
  }

  @override
  String get repeatNone => 'Aucun';

  @override
  String get repeatVerse => 'Répéter le verset';

  @override
  String get repeatChapter => 'Répéter le chapitre';

  @override
  String get audioRecordingSource => 'Source d’enregistrement';

  @override
  String get sourceHEB => 'Shmueloff';

  @override
  String get sourceRDB => 'Dan Beeri';

  @override
  String get sourceTK => 'Moderne';

  @override
  String get sourceJH => 'Lucien';

  @override
  String get downloadAudio => 'Télécharger l’audio';

  @override
  String audioNotDownloaded(String book, int chapter) {
    return 'L’audio de $book $chapter n’est pas sur votre appareil.';
  }

  @override
  String get audioNotAvailable =>
      'L’audio n’est pas disponible pour ce chapitre.';

  @override
  String get verseCopied => 'Verset copié dans le presse-papiers';

  @override
  String get downloads => 'Téléchargements';

  @override
  String get audio => 'Audio';

  @override
  String get bibles => 'Bibles';

  @override
  String get lexicons => 'Lexiques';

  @override
  String get oldTestament => 'Ancien Testament';

  @override
  String get newTestament => 'Nouveau Testament';

  @override
  String deleteAudioConfirmation(String book) {
    return 'Supprimer tout l’audio de $book ?';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String downloadAudioConfirmation(int count, String book) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Télécharger $count chapitres manquants de $book ?',
      one: 'Télécharger 1 chapitre manquant de $book ?',
    );
    return '$_temp0';
  }

  @override
  String get progress => 'Progression';

  @override
  String get goals => 'Objectifs';

  @override
  String get bySection => 'Par section';

  @override
  String get byBook => 'Par livre';

  @override
  String get week => 'Semaine';

  @override
  String get month => 'Mois';

  @override
  String months(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Jan',
      '2': 'Fév',
      '3': 'Mar',
      '4': 'Avr',
      '5': 'Mai',
      '6': 'Juin',
      '7': 'Juil',
      '8': 'Aoû',
      '9': 'Sep',
      '10': 'Oct',
      '11': 'Nov',
      '12': 'Déc',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get startSession => 'Commencer la session';

  @override
  String get start => 'Commencer';

  @override
  String get resume => 'Reprendre';

  @override
  String get whereYouLeftOff => 'Là où vous vous êtes arrêté';

  @override
  String get changeGoal => 'Modifier l’objectif';

  @override
  String get chapterShort => 'CH';

  @override
  String get dailyGoal => 'Objectif quotidien';

  @override
  String get minutes => 'minutes';

  @override
  String get verses => 'versets';

  @override
  String get minutesShort => 'min';

  @override
  String get versesShort => 'v';

  @override
  String get dailyGoalReached => 'objectif quotidien atteint';

  @override
  String get total => 'Total';

  @override
  String dayOfWeek(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      '1': 'Lun',
      '2': 'Mar',
      '3': 'Mer',
      '4': 'Jeu',
      '5': 'Ven',
      '6': 'Sam',
      '7': 'Dim',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get dismiss => 'FERMER';

  @override
  String sessions(Object count) {
    return 'SÉANCES: $count';
  }

  @override
  String get sessionTotal => 'TOTAL DE SESSION';

  @override
  String get inProgress => 'En cours';

  @override
  String get goalType => 'Type d’objectif';

  @override
  String get target => 'Objectif';

  @override
  String get save => 'Enregistrer';

  @override
  String get hide => 'Masquer';

  @override
  String get minutesPerDay => 'Minutes par jour';

  @override
  String get versesPerDay => 'Versets par jour';

  @override
  String get goalReachedMessage => 'Tu as atteint ton objectif 🎉';

  @override
  String get continueReadingPrompt => 'Continuer ta session de lecture ?';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get bookGenesis => 'Genèse';

  @override
  String get bookExodus => 'Exode';

  @override
  String get bookLeviticus => 'Lévitique';

  @override
  String get bookNumbers => 'Nombres';

  @override
  String get bookDeuteronomy => 'Deutéronome';

  @override
  String get bookJoshua => 'Josué';

  @override
  String get bookJudges => 'Juges';

  @override
  String get bookRuth => 'Ruth';

  @override
  String get book1Samuel => '1 Samuel';

  @override
  String get book2Samuel => '2 Samuel';

  @override
  String get book1Kings => '1 Rois';

  @override
  String get book2Kings => '2 Rois';

  @override
  String get book1Chronicles => '1 Chroniques';

  @override
  String get book2Chronicles => '2 Chroniques';

  @override
  String get bookEzra => 'Esdras';

  @override
  String get bookNehemiah => 'Néhémie';

  @override
  String get bookEsther => 'Esther';

  @override
  String get bookJob => 'Job';

  @override
  String get bookPsalms => 'Psaumes';

  @override
  String get bookProverbs => 'Proverbes';

  @override
  String get bookEcclesiastes => 'Ecclésiaste';

  @override
  String get bookSongOfSolomon => 'Cantique des cantiques';

  @override
  String get bookIsaiah => 'Ésaïe';

  @override
  String get bookJeremiah => 'Jérémie';

  @override
  String get bookLamentations => 'Lamentations';

  @override
  String get bookEzekiel => 'Ézéchiel';

  @override
  String get bookDaniel => 'Daniel';

  @override
  String get bookHosea => 'Osée';

  @override
  String get bookJoel => 'Joël';

  @override
  String get bookAmos => 'Amos';

  @override
  String get bookObadiah => 'Abdias';

  @override
  String get bookJonah => 'Jonas';

  @override
  String get bookMicah => 'Michée';

  @override
  String get bookNahum => 'Nahum';

  @override
  String get bookHabakkuk => 'Habacuc';

  @override
  String get bookZephaniah => 'Sophonie';

  @override
  String get bookHaggai => 'Aggée';

  @override
  String get bookZechariah => 'Zacharie';

  @override
  String get bookMalachi => 'Malachie';

  @override
  String get bookMatthew => 'Matthieu';

  @override
  String get bookMark => 'Marc';

  @override
  String get bookLuke => 'Luc';

  @override
  String get bookJohn => 'Jean';

  @override
  String get bookActs => 'Actes';

  @override
  String get bookRomans => 'Romains';

  @override
  String get book1Corinthians => '1 Corinthiens';

  @override
  String get book2Corinthians => '2 Corinthiens';

  @override
  String get bookGalatians => 'Galates';

  @override
  String get bookEphesians => 'Éphésiens';

  @override
  String get bookPhilippians => 'Philippiens';

  @override
  String get bookColossians => 'Colossiens';

  @override
  String get book1Thessalonians => '1 Thessaloniciens';

  @override
  String get book2Thessalonians => '2 Thessaloniciens';

  @override
  String get book1Timothy => '1 Timothée';

  @override
  String get book2Timothy => '2 Timothée';

  @override
  String get bookTitus => 'Tite';

  @override
  String get bookPhilemon => 'Philémon';

  @override
  String get bookHebrews => 'Hébreux';

  @override
  String get bookJames => 'Jacques';

  @override
  String get book1Peter => '1 Pierre';

  @override
  String get book2Peter => '2 Pierre';

  @override
  String get book1John => '1 Jean';

  @override
  String get book2John => '2 Jean';

  @override
  String get book3John => '3 Jean';

  @override
  String get bookJude => 'Jude';

  @override
  String get bookRevelation => 'Apocalypse';
}
