// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get about => 'Acerca de';

  @override
  String get appName => 'Herramientas Bíblicas Globales';

  @override
  String get sourceCode => 'Código fuente';

  @override
  String get emailCopied => 'Correo electrónico copiado';

  @override
  String get settings => 'Ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get currentLanguage => 'Español';

  @override
  String get textSize => 'Tamaño del texto';

  @override
  String get hebrewGreekTextSize => 'Hebreo/Griego';

  @override
  String get secondPanelTextSize => 'Segundo panel';

  @override
  String get lexiconTextSize => 'Léxico';

  @override
  String get downloadGlossesMessage =>
      'Para mostrar los significados en Español (glosas) de las palabras hebreas, es necesario descargar los datos. ¿Desea descargarlos ahora?';

  @override
  String get useEnglish => 'Usar Inglés';

  @override
  String get download => 'Descargar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get downloadingGlossesMessage =>
      'Descargando significados (glosas) de las palabras en Español...';

  @override
  String get downloadComplete => 'Descarga completa.';

  @override
  String get downloadFailed =>
      'La descarga falló. Por favor, revise su conexión al internet e inténtelo de nuevo.';

  @override
  String get nextChapter => 'Siguiente capítulo';

  @override
  String get root => 'Raíz';

  @override
  String get exact => 'Exacto';

  @override
  String get search => 'Buscar';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '1 resultado',
      zero: 'No hay resultados',
    );
    return '$_temp0';
  }

  @override
  String get repeatNone => 'Ninguno';

  @override
  String get repeatVerse => 'Repetir versículo';

  @override
  String get repeatChapter => 'Repetir capítulo';

  @override
  String get audioRecordingSource => 'Fuente de grabación';

  @override
  String get sourceHEB => 'Shmueloff';

  @override
  String get sourceRDB => 'Dan Beeri';

  @override
  String get downloadAudio => 'Descargar Audio';

  @override
  String audioNotDownloaded(String book, int chapter) {
    return 'El audio de $book $chapter no está en su dispositivo.';
  }

  @override
  String get audioNotAvailable =>
      'El audio no está disponible para este capítulo.';

  @override
  String get verseCopied => 'Versículo copiado al portapapeles';

  @override
  String get downloads => 'Descargas';

  @override
  String get audio => 'Audio';

  @override
  String get bibles => 'Biblias';

  @override
  String get lexicons => 'Léxicos';

  @override
  String get oldTestament => 'Antiguo Testamento';

  @override
  String deleteAudioConfirmation(String book) {
    return '¿Eliminar todo el audio de $book?';
  }

  @override
  String get delete => 'Eliminar';

  @override
  String downloadAudioConfirmation(int count, String book) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Descargar $count capítulos faltantes de $book?',
      one: '¿Descargar 1 capítulo faltante de $book?',
    );
    return '$_temp0';
  }

  @override
  String get bookGenesis => 'Génesis';

  @override
  String get bookExodus => 'Éxodo';

  @override
  String get bookLeviticus => 'Levítico';

  @override
  String get bookNumbers => 'Números';

  @override
  String get bookDeuteronomy => 'Deuteronomio';

  @override
  String get bookJoshua => 'Josué';

  @override
  String get bookJudges => 'Jueces';

  @override
  String get bookRuth => 'Rut';

  @override
  String get book1Samuel => '1 Samuel';

  @override
  String get book2Samuel => '2 Samuel';

  @override
  String get book1Kings => '1 Reyes';

  @override
  String get book2Kings => '2 Reyes';

  @override
  String get book1Chronicles => '1 Crónicas';

  @override
  String get book2Chronicles => '2 Crónicas';

  @override
  String get bookEzra => 'Esdras';

  @override
  String get bookNehemiah => 'Nehemías';

  @override
  String get bookEsther => 'Ester';

  @override
  String get bookJob => 'Job';

  @override
  String get bookPsalms => 'Salmos';

  @override
  String get bookProverbs => 'Proverbios';

  @override
  String get bookEcclesiastes => 'Eclesiastés';

  @override
  String get bookSongOfSolomon => 'Cantares';

  @override
  String get bookIsaiah => 'Isaías';

  @override
  String get bookJeremiah => 'Jeremías';

  @override
  String get bookLamentations => 'Lamentaciones';

  @override
  String get bookEzekiel => 'Ezequiel';

  @override
  String get bookDaniel => 'Daniel';

  @override
  String get bookHosea => 'Oseas';

  @override
  String get bookJoel => 'Joel';

  @override
  String get bookAmos => 'Amós';

  @override
  String get bookObadiah => 'Abdías';

  @override
  String get bookJonah => 'Jonás';

  @override
  String get bookMicah => 'Miqueas';

  @override
  String get bookNahum => 'Nahum';

  @override
  String get bookHabakkuk => 'Habacuc';

  @override
  String get bookZephaniah => 'Sofonías';

  @override
  String get bookHaggai => 'Hageo';

  @override
  String get bookZechariah => 'Zacarías';

  @override
  String get bookMalachi => 'Malaquías';

  @override
  String get bookMatthew => 'Mateo';

  @override
  String get bookMark => 'Marcos';

  @override
  String get bookLuke => 'Lucas';

  @override
  String get bookJohn => 'Juan';

  @override
  String get bookActs => 'Hechos';

  @override
  String get bookRomans => 'Romanos';

  @override
  String get book1Corinthians => '1 Corintios';

  @override
  String get book2Corinthians => '2 Corintios';

  @override
  String get bookGalatians => 'Gálatas';

  @override
  String get bookEphesians => 'Efesios';

  @override
  String get bookPhilippians => 'Filipenses';

  @override
  String get bookColossians => 'Colosenses';

  @override
  String get book1Thessalonians => '1 Tesalonicenses';

  @override
  String get book2Thessalonians => '2 Tesalonicenses';

  @override
  String get book1Timothy => '1 Timoteo';

  @override
  String get book2Timothy => '2 Timoteo';

  @override
  String get bookTitus => 'Tito';

  @override
  String get bookPhilemon => 'Filemón';

  @override
  String get bookHebrews => 'Hebreos';

  @override
  String get bookJames => 'Santiago';

  @override
  String get book1Peter => '1 Pedro';

  @override
  String get book2Peter => '2 Pedro';

  @override
  String get book1John => '1 Juan';

  @override
  String get book2John => '2 Juan';

  @override
  String get book3John => '3 Juan';

  @override
  String get bookJude => 'Judas';

  @override
  String get bookRevelation => 'Apocalipsis';
}
