import 'package:flutter/foundation.dart';
import 'package:gbt/l10n/app_languages.dart';
import 'package:gbt/services/files/file_service.dart'; // Import your FileType enum

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
  /// Production asset host (used in release builds).
  static const String _prodBaseHost = "https://assets.globalbibletools.com";

  /// Local development asset host. Override at build time for the target:
  ///
  ///   * Android emulator:   --dart-define=ASSETS_BASE_URL=http://10.0.2.2:4566/assets
  ///   * iOS simulator:       --dart-define=ASSETS_BASE_URL=http://localhost:4566/assets
  ///   * Physical device:     --dart-define=ASSETS_BASE_URL=http://YOUR_LAN_IP:4566/assets
  ///
  /// Defaults to the Android emulator address so `flutter run` on an emulator
  /// works out of the box against the local MiniStack instance.
  static const String _devBaseHost = String.fromEnvironment(
    'ASSETS_BASE_URL',
    defaultValue: 'http://10.0.2.2:4566/assets',
  );

  /// Resolved asset base URL. Release builds hit the CDN; debug builds hit the
  /// local MiniStack S3 bucket (overridable via --dart-define).
  static final String _baseHost =
      kReleaseMode ? _prodBaseHost : _devBaseHost;

  // --- BIBLE ASSETS ---

  /// Returns the asset config for a specific language bible database.
  /// Example: remote: .../bibles/spa_blm.db.zip -> local: spa_blm.db
  RemoteAsset getBibleAsset(String langCode) {
    final filename = AppLanguages.getConfig(langCode).bibleFilename;

    return RemoteAsset(
      remoteUrl: '$_baseHost/bibles/v1/$filename.zip',
      localRelativePath: filename,
      fileType: FileType.bible,
      isZip: true,
    );
  }

  // --- GLOSS ASSETS ---

  RemoteAsset getGlossAsset(String langCode) {
    final filename = '$langCode.db';

    return RemoteAsset(
      remoteUrl: '$_baseHost/glosses/v1/$filename.zip',
      localRelativePath: filename,
      fileType: FileType.gloss,
      isZip: true,
    );
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
    required String recordingId,
  }) {
    if (bookId < 1 || bookId > _bookKeys.length) return null;

    final bookKey = _bookKeys[bookId - 1];
    final chapterStr = chapter.toString().padLeft(3, '0');
    final filename = '$chapterStr.mp3';

    final relativePath = '$recordingId/$bookKey/$filename';

    return RemoteAsset(
      remoteUrl: '$_baseHost/audio/$relativePath',
      localRelativePath: relativePath,
      fileType: FileType.audio,
      isZip: false,
    );
  }
}
