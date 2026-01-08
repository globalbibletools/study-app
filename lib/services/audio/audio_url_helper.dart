class AudioUrlHelper {
  static const String _baseUrl = "https://assets.globalbibletools.com/audio";

  // Your provided keys list
  static const List<String> _bookKeys = [
    'Gen',
    'Exo',
    'Lev',
    'Num',
    'Deu',
    'Jos',
    'Jdg',
    'Rut',
    '1Sa',
    '2Sa',
    '1Ki',
    '2Ki',
    '1Ch',
    '2Ch',
    'Ezr',
    'Neh',
    'Est',
    'Job',
    'Psa',
    'Pro',
    'Ecc',
    'Sng',
    'Isa',
    'Jer',
    'Lam',
    'Ezk',
    'Dan',
    'Hos',
    'Jol',
    'Amo',
    'Oba',
    'Jon',
    'Mic',
    'Nam',
    'Hab',
    'Zep',
    'Hag',
    'Zec',
    'Mal',
    'Mat',
    'Mrk',
    'Luk',
    'Jhn',
    'Act',
    'Rom',
    '1Co',
    '2Co',
    'Gal',
    'Eph',
    'Php',
    'Col',
    '1Th',
    '2Th',
    '1Ti',
    '2Ti',
    'Tit',
    'Phm',
    'Heb',
    'Jas',
    '1Pe',
    '2Pe',
    '1Jn',
    '2Jn',
    '3Jn',
    'Jud',
    'Rev',
  ];

  static String getAudioUrl({
    required int bookId,
    required int chapter,
    String recordingId = 'HEB',
  }) {
    // Safety check for bookId (1-66)
    if (bookId < 1 || bookId > _bookKeys.length) return "";

    final bookKey =
        _bookKeys[bookId - 1]; // Array is 0-indexed, ID is 1-indexed

    // Chapter needs to be padded to 3 digits (e.g., 1 -> "001")
    final chapterStr = chapter.toString().padLeft(3, '0');

    return "$_baseUrl/$recordingId/$bookKey/$chapterStr.mp3";
  }
}
