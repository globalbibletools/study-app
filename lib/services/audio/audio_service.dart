import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gbt/services/audio/audio_timing.dart';
import 'package:gbt/services/audio/audio_timing_database.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';

class AudioMissingException implements Exception {
  final int bookId;
  final int chapter;
  AudioMissingException(this.bookId, this.chapter);
}

enum Testament {
  ot('OT'),
  nt('NT');

  final String key;
  const Testament(this.key);
}

class AudioService {
    final _resourceService = getIt<ResourceService>();
    final _downloadService = getIt<DownloadService>();

    String? _currentSpeaker;
    final Map<int, AudioTimingDatabase> _timingDbs = {};

    static const int _newTestamentStartBookId = 40;
    static Testament testamentForBookId(int bookId) {
        return bookId < _newTestamentStartBookId ? Testament.ot : Testament.nt;
    }

    String? buildResourceId(String source, int bookId) {
        if (bookId < 0 || bookId >= bookKeys.length) return null;
        final bookKey = bookKeys[bookId - 1];
        final testament = testamentForBookId(bookId);

        return "${testament.key}/$source/$bookKey";
    }

    Future<List<Resource>> getSpeakers(Testament testament) async {
        return _resourceService.getResourcesByPath(
          ResourceType.audio,
          [PathMatcher.exact(testament.key), PathMatcher.any()],
        );
    }

    Future<({String audioUrl, List<AudioTiming> timings})> getChapterData(String source, int bookId, int chapter) async {
        final resourceId = buildResourceId(source, bookId);
        if (resourceId == null) throw AudioMissingException(bookId, chapter);

        if (source != _currentSpeaker) {
            _currentSpeaker = source;
            _timingDbs.clear();
        }

        final fileName = "${chapter.toString().padLeft(3, '0')}.mp3";

        final db = _timingDbs[bookId] ?? await _loadTimingDb(source, bookId, chapter, resourceId);
        _timingDbs.putIfAbsent(bookId, () => db);

        final timings = db.getTimingsForChapter(chapter - 1);
        if (timings == null) throw AudioMissingException(bookId, chapter);

        // --- Audio URL ---
        try {
            final localDirectory = await _resourceService.getResourceLocalPath(ResourceType.audio, resourceId);
            final fullPath = "$localDirectory/$fileName";

            final exists = await File(fullPath).exists();
            if (!exists) {
                throw AudioMissingException(bookId, chapter);
            }

            final url = Uri.file(fullPath).toString();
            return (audioUrl: url, timings: timings);
        } on ResourceMissingException {
            final remoteUrl = await _resourceService.getResourceStreamingUrl(ResourceType.audio, resourceId);
            final url = "$remoteUrl/$fileName";

            final exists = await _downloadService.checkExistence(url);
            if (!exists) {
                throw AudioMissingException(bookId, chapter);
            }

            return (audioUrl: url, timings: timings);
        }
    }

    Future<AudioTimingDatabase> _loadTimingDb(String source, int bookId, int chapter, String resourceId) async {
        try {
            final localDirectory = await _resourceService.getResourceLocalPath(ResourceType.audio, resourceId);
            final timingsFile = File('$localDirectory/timings.bin');
            if (!await timingsFile.exists()) {
                debugPrint("Local timings file missing: $localDirectory/timings.bin");
                throw AudioMissingException(bookId, chapter);
            }
            return AudioTimingDatabase.openFile('$localDirectory/timings.bin');
        } on ResourceMissingException {
            final remoteUrl = await _resourceService.getResourceStreamingUrl(ResourceType.audio, resourceId);
            final timingsUrl = '$remoteUrl/timings.bin';

            try {
                final bytes = await _downloadService.getBytes(timingsUrl);
                return AudioTimingDatabase(bytes);
            } on HttpNotFoundException {
                debugPrint("Remote timings file missing: $timingsUrl");
                throw AudioMissingException(bookId, chapter);
            }
        }
    }
}

const List<String> bookKeys = [
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
