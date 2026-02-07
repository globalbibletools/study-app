import 'package:studyapp/services/files/file_service.dart'; // Import your FileType enum

class RemoteAsset {
  final String remoteUrl;
  final String localRelativePath;
  final FileType fileType;
  final bool isZip;

  RemoteAsset({
    required this.remoteUrl,
    required this.localRelativePath,
    required this.fileType,
    this.isZip = false,
  });
}

class RemoteAssetService {
  static const String _baseHost = "https://assets.globalbibletools.com";

  // --- BIBLE ASSETS ---

  /// Returns the asset config for a specific language bible database.
  /// Example: remote: .../bibles/spa_blm.db.zip -> local: spa_blm.db
  RemoteAsset getBibleAsset(String langCode) {
    final filename = _getBibleFilename(langCode);

    return RemoteAsset(
      remoteUrl: '$_baseHost/bibles/$filename.zip',
      localRelativePath: 'bibles/$filename',
      fileType: FileType.bible,
      isZip: true,
    );
  }

  String _getBibleFilename(String langCode) {
    switch (langCode) {
      case 'es':
        return 'spa_blm.db'; // Spanish
      case 'fr':
        return 'fra_lsg.db'; // French
      case 'pt':
        return 'por_blj.db'; // Portuguese
      case 'ar':
        return 'arb_vdv.db'; // Arabic
      default:
        return '$langCode.db';
    }
  }

  // --- GLOSS ASSETS ---

  /// Returns the asset config for a gloss database.
  RemoteAsset getGlossAsset(String langCode) {
    final filename = _getGlossFilename(langCode);

    return RemoteAsset(
      remoteUrl: '$_baseHost/glosses/$filename.zip',
      localRelativePath: 'glosses/$filename',
      fileType: FileType.gloss,
      isZip: true,
    );
  }

  String _getGlossFilename(String langCode) {
    switch (langCode) {
      case 'es':
        return 'spa.db'; // Spanish
      case 'fr':
        return 'fra.db'; // French
      case 'pt':
        return 'por.db'; // Portuguese
      case 'ar':
        return 'are.db'; // Arabic
      default:
        return '$langCode.db';
    }
  }

  // --- AUDIO ASSETS ---

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

  /// Returns asset config for a single chapter audio file.
  /// Audio is usually streamed or downloaded as raw MP3, so isZip = false.
  RemoteAsset? getAudioChapterAsset({
    required int bookId,
    required int chapter,
    String recordingId = 'HEB',
  }) {
    if (bookId < 1 || bookId > _bookKeys.length) return null;

    final bookKey = _bookKeys[bookId - 1];
    final chapterStr = chapter.toString().padLeft(3, '0');
    final filename = '$chapterStr.mp3';

    // Remote: .../audio/HEB/Gen/001.mp3
    // Local:  .../audio/HEB/Gen/001.mp3
    final relativePath = '$recordingId/$bookKey/$filename';

    return RemoteAsset(
      remoteUrl: '$_baseHost/audio/$relativePath',
      localRelativePath: 'audio/$relativePath',
      fileType: FileType.audio,
      isZip: false,
    );
  }
}
