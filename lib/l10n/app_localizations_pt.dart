// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get theme => 'Tema';

  @override
  String get systemDefault => 'Padrão do sistema';

  @override
  String get lightTheme => 'Claro';

  @override
  String get darkTheme => 'Escuro';

  @override
  String get about => 'Sobre';

  @override
  String get appName => 'Ferramentas Bíblicas Globais';

  @override
  String get sourceCode => 'Código-fonte';

  @override
  String get emailCopied => 'E-mail copiado';

  @override
  String get settings => 'Configurações';

  @override
  String get language => 'Idioma';

  @override
  String get currentLanguage => 'Português';

  @override
  String get textSize => 'Tamanho do texto';

  @override
  String get hebrewGreekTextSize => 'Hebraico/Greco';

  @override
  String get secondPanelTextSize => 'Segundo painel';

  @override
  String get lexiconTextSize => 'Léxico';

  @override
  String get downloadResourcesMessage =>
      'Para usar este idioma, precisamos baixar recursos adicionais.';

  @override
  String get useEnglish => 'Usar inglês';

  @override
  String get download => 'Baixar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get downloadComplete => 'Download concluído.';

  @override
  String get downloadFailed =>
      'O download falhou. Verifique sua conexão com a internet e tente novamente.';

  @override
  String get nextChapter => 'Próximo capítulo';

  @override
  String get root => 'Raiz';

  @override
  String get exact => 'Exato';

  @override
  String get search => 'Pesquisar';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '1 resultado',
      zero: 'Nenhum resultado',
    );
    return '$_temp0';
  }

  @override
  String get repeatNone => 'Nenhum';

  @override
  String get repeatVerse => 'Repetir versículo';

  @override
  String get repeatChapter => 'Repetir capítulo';

  @override
  String get audioRecordingSource => 'Fonte de gravação';

  @override
  String get sourceHEB => 'Shmueloff';

  @override
  String get sourceRDB => 'Dan Beeri';

  @override
  String get downloadAudio => 'Baixar áudio';

  @override
  String audioNotDownloaded(String book, int chapter) {
    return 'O áudio de $book $chapter não está no seu dispositivo.';
  }

  @override
  String get audioNotAvailable =>
      'O áudio não está disponível para este capítulo.';

  @override
  String get verseCopied => 'Versículo copiado para a área de transferência';

  @override
  String get downloads => 'Downloads';

  @override
  String get audio => 'Áudio';

  @override
  String get bibles => 'Bíblias';

  @override
  String get lexicons => 'Léxicos';

  @override
  String get oldTestament => 'Antigo Testamento';

  @override
  String deleteAudioConfirmation(String book) {
    return 'Excluir todo o áudio de $book?';
  }

  @override
  String get delete => 'Excluir';

  @override
  String downloadAudioConfirmation(int count, String book) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Baixar $count capítulos ausentes de $book?',
      one: 'Baixar 1 capítulo ausente de $book?',
    );
    return '$_temp0';
  }

  @override
  String get bookGenesis => 'Gênesis';

  @override
  String get bookExodus => 'Êxodo';

  @override
  String get bookLeviticus => 'Levítico';

  @override
  String get bookNumbers => 'Números';

  @override
  String get bookDeuteronomy => 'Deuteronômio';

  @override
  String get bookJoshua => 'Josué';

  @override
  String get bookJudges => 'Juízes';

  @override
  String get bookRuth => 'Rute';

  @override
  String get book1Samuel => '1 Samuel';

  @override
  String get book2Samuel => '2 Samuel';

  @override
  String get book1Kings => '1 Reis';

  @override
  String get book2Kings => '2 Reis';

  @override
  String get book1Chronicles => '1 Crônicas';

  @override
  String get book2Chronicles => '2 Crônicas';

  @override
  String get bookEzra => 'Esdras';

  @override
  String get bookNehemiah => 'Neemias';

  @override
  String get bookEsther => 'Ester';

  @override
  String get bookJob => 'Jó';

  @override
  String get bookPsalms => 'Salmos';

  @override
  String get bookProverbs => 'Provérbios';

  @override
  String get bookEcclesiastes => 'Eclesiastes';

  @override
  String get bookSongOfSolomon => 'Cânticos';

  @override
  String get bookIsaiah => 'Isaías';

  @override
  String get bookJeremiah => 'Jeremias';

  @override
  String get bookLamentations => 'Lamentações';

  @override
  String get bookEzekiel => 'Ezequiel';

  @override
  String get bookDaniel => 'Daniel';

  @override
  String get bookHosea => 'Oséias';

  @override
  String get bookJoel => 'Joel';

  @override
  String get bookAmos => 'Amós';

  @override
  String get bookObadiah => 'Obadias';

  @override
  String get bookJonah => 'Jonas';

  @override
  String get bookMicah => 'Miquéias';

  @override
  String get bookNahum => 'Naum';

  @override
  String get bookHabakkuk => 'Habacuque';

  @override
  String get bookZephaniah => 'Sofonias';

  @override
  String get bookHaggai => 'Ageu';

  @override
  String get bookZechariah => 'Zacarias';

  @override
  String get bookMalachi => 'Malaquias';

  @override
  String get bookMatthew => 'Mateus';

  @override
  String get bookMark => 'Marcos';

  @override
  String get bookLuke => 'Lucas';

  @override
  String get bookJohn => 'João';

  @override
  String get bookActs => 'Atos';

  @override
  String get bookRomans => 'Romanos';

  @override
  String get book1Corinthians => '1 Coríntios';

  @override
  String get book2Corinthians => '2 Coríntios';

  @override
  String get bookGalatians => 'Gálatas';

  @override
  String get bookEphesians => 'Efésios';

  @override
  String get bookPhilippians => 'Filipenses';

  @override
  String get bookColossians => 'Colossenses';

  @override
  String get book1Thessalonians => '1 Tessalonicenses';

  @override
  String get book2Thessalonians => '2 Tessalonicenses';

  @override
  String get book1Timothy => '1 Timóteo';

  @override
  String get book2Timothy => '2 Timóteo';

  @override
  String get bookTitus => 'Tito';

  @override
  String get bookPhilemon => 'Filemom';

  @override
  String get bookHebrews => 'Hebreus';

  @override
  String get bookJames => 'Tiago';

  @override
  String get book1Peter => '1 Pedro';

  @override
  String get book2Peter => '2 Pedro';

  @override
  String get book1John => '1 João';

  @override
  String get book2John => '2 João';

  @override
  String get book3John => '3 João';

  @override
  String get bookJude => 'Judas';

  @override
  String get bookRevelation => 'Apocalipse';
}
