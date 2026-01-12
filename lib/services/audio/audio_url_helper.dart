class AudioUrlHelper {
  static const String _baseUrl = "https://assets.globalbibletools.com/audio";

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

  /// Returns the relative local path: "recordingId/BookKey/Chapter.mp3"
  static String getLocalRelativePath({
    required int bookId,
    required int chapter,
    String recordingId = 'HEB',
  }) {
    final parts = _getParts(bookId, chapter);
    if (parts == null) return "";
    return "$recordingId/${parts.bookKey}/${parts.chapterStr}.mp3";
  }

  static String getAudioUrl({
    required int bookId,
    required int chapter,
    String recordingId = 'HEB',
  }) {
    final parts = _getParts(bookId, chapter);
    if (parts == null) return "";
    return "$_baseUrl/$recordingId/${parts.bookKey}/${parts.chapterStr}.mp3";
  }

  // Helper to get the filename parts (e.g. 'Gen', '001')
  static ({String bookKey, String chapterStr})? _getParts(
    int bookId,
    int chapter,
  ) {
    if (bookId < 1 || bookId > _bookKeys.length) return null;
    final bookKey = _bookKeys[bookId - 1];
    final chapterStr = chapter.toString().padLeft(3, '0');
    return (bookKey: bookKey, chapterStr: chapterStr);
  }
}
