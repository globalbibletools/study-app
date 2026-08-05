// Bundles a subset of audio books for local MiniStack testing.
//
// For each speaker, downloads Genesis, Isaiah, Matthew, and Romans from the
// production CDN, packages each book as a zip, and writes an
// `audio/v1/manifest.jsonl` into the MiniStack seed assets.
//
// Run from the project root:
//
//   dart run tools/package_audio_manifest.dart
//
// Re-runs are cheap: already-downloaded mp3s are skipped, so only the zips and
// manifest are rebuilt.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Production CDN base. Chapter files live at `{base}/audio/{speaker}/{book}/{NNN}.mp3`.
const String _cdnBase = 'https://assets.globalbibletools.com';

/// MiniStack seed assets root (served at `{devBase}/assets/...`).
///
/// Anchored at the project root (the parent of this `tools/` package) so the
/// script works regardless of the working directory it is launched from.
final Directory _seedRoot = Directory(
  p.normalize(
    p.join(p.dirname(p.fromUri(Platform.script)), '..', 'ministack', 'assets'),
  ),
);

/// Audio versioned directory inside the seed root.
final String _audioV1 = p.join(_seedRoot.path, 'audio', 'v1');

/// Fixed timestamp for reproducible manifest output.
const String _updatedAt = '2025-01-15T00:00:00Z';

/// Caps how many chapter files are kept per book, to keep the repo seed small.
/// Extra cached mp3s beyond this are deleted and excluded from the zips.
const int _maxChaptersPerBook = 3;

class Speaker {
  final String id;
  final String displayName;
  const Speaker(this.id, this.displayName);
}

class Book {
  final String key;
  final String name;
  final int chapterCount;
  const Book(this.key, this.name, this.chapterCount);
}

const List<Speaker> speakers = [
  Speaker('RDB', 'Dan Beeri'),
  Speaker('HEB', 'Shmueloff'),
  Speaker('TK', 'Modern'),
  Speaker('JH', 'Lucian'),
];

const List<Book> books = [
  Book('Gen', 'Genesis', 50),
  Book('Isa', 'Isaiah', 66),
  Book('Mat', 'Matthew', 28),
  Book('Rom', 'Romans', 16),
];

class BookEntry {
  final String id;
  final String url;
  final String sha256;
  final int size;
  final String resourceName;
  final String creatorName;
  final int chapterCount;

  BookEntry({
    required this.id,
    required this.url,
    required this.sha256,
    required this.size,
    required this.resourceName,
    required this.creatorName,
    required this.chapterCount,
  });

  String get manifestLine {
    final map = <String, Object?>{
      'id': id,
      'updatedAt': _updatedAt,
      'sha256': sha256,
      'size': size,
      'url': url,
      'resourceName': resourceName,
      'creatorName': creatorName,
    };
    return jsonEncode(map);
  }
}

Future<void> main() async {
  final client = http.Client();
  final bookEntries = <BookEntry>[];
  final speakerEntries = <Speaker>[];

  for (final speaker in speakers) {
    int booksForSpeaker = 0;

    for (final book in books) {
      final chaptersDir =
          Directory(p.join(_seedRoot.path, 'audio', speaker.id, book.key));
      await chaptersDir.create(recursive: true);

      // The repo seed only keeps the first few chapters per book. Delete any
      // cached mp3s beyond the cap so re-runs after lowering the cap don't
      // leave stale files behind.
      final chapterLimit =
          book.chapterCount < _maxChaptersPerBook
              ? book.chapterCount
              : _maxChaptersPerBook;
      await _pruneExtraChapters(chaptersDir, chapterLimit);

      final chapterFiles = <File>[];
      int downloaded = 0;
      int skipped = 0;

      for (var chapter = 1; chapter <= chapterLimit; chapter++) {
        final padded = chapter.toString().padLeft(3, '0');
        final filename = '$padded.mp3';
        final localFile = File(p.join(chaptersDir.path, filename));

        if (await localFile.exists()) {
          chapterFiles.add(localFile);
          skipped++;
          continue;
        }

        final remoteUrl =
            '$_cdnBase/audio/${speaker.id}/${book.key}/$filename';
        final res = await client.get(Uri.parse(remoteUrl));

        // Missing keys on the CDN return 403 (or 404); treat both as absent.
        if (res.statusCode == 403 || res.statusCode == 404) {
          continue;
        }
        if (res.statusCode != HttpStatus.ok) {
          stderr.writeln('  ! $remoteUrl -> HTTP ${res.statusCode}, skipping');
          continue;
        }

        await localFile.writeAsBytes(res.bodyBytes, flush: true);
        chapterFiles.add(localFile);
        downloaded++;

        if (downloaded % 10 == 0) {
          stdout.writeln('    ${speaker.id}/${book.key}: $downloaded files...');
        }
      }

      if (chapterFiles.isEmpty) {
        stdout.writeln(
            '${speaker.id}/${book.key}: no chapters available, skipping.');
        continue;
      }

      booksForSpeaker++;
      final entry = await _buildBookZip(
        speaker: speaker,
        book: book,
        chapterFiles: chapterFiles,
      );
      bookEntries.add(entry);
      stdout.writeln(
          '${speaker.id}/${book.key}: ${chapterFiles.length} chapters '
          '($downloaded downloaded, $skipped cached) -> ${entry.url} '
          '(${entry.size} bytes)');
    }

    // Speaker (group) row: present only if at least one book was packaged.
    if (booksForSpeaker > 0) {
      speakerEntries.add(speaker);
    }
  }

  client.close();

  // Write the manifest: speakers first (group rows), then books (leaf rows).
  final manifest = <String>[];
  for (final speaker in speakerEntries) {
    final map = <String, Object?>{
      'id': speaker.id,
      'updatedAt': _updatedAt,
      'sha256': null,
      'size': null,
      'url': null,
      'resourceName': speaker.displayName,
      'creatorName': null,
    };
    manifest.add(jsonEncode(map));
  }
  for (final entry in bookEntries) {
    manifest.add(entry.manifestLine);
  }

  final manifestFile = File(p.join(_audioV1, 'manifest.jsonl'));
  await manifestFile.parent.create(recursive: true);
  await manifestFile.writeAsString('${manifest.join('\n')}\n');

  stdout.writeln('');
  stdout.writeln('Wrote ${manifestFile.path}');
  stdout.writeln('  ${speakerEntries.length} speaker rows, '
      '${bookEntries.length} book rows');
}

Future<BookEntry> _buildBookZip({
  required Speaker speaker,
  required Book book,
  required List<File> chapterFiles,
}) async {
  final archive = Archive();
  for (final file in chapterFiles) {
    final bytes = await file.readAsBytes();
    archive.addFile(
      ArchiveFile(p.basename(file.path), bytes.length, bytes),
    );
  }
  final zipBytes = ZipEncoder().encode(archive);

  final zipRelPath = 'audio/v1/${speaker.id}/${book.key}.zip';
  final zipAbsPath = p.join(_seedRoot.path, zipRelPath);
  await File(zipAbsPath).parent.create(recursive: true);
  await File(zipAbsPath).writeAsBytes(zipBytes, flush: true);

  final sha256 = sha256Convert(zipBytes);
  final size = zipBytes.length;

  return BookEntry(
    id: '${speaker.id}/${book.key}',
    url: zipRelPath,
    sha256: sha256,
    size: size,
    resourceName: book.name,
    creatorName: speaker.displayName,
    chapterCount: chapterFiles.length,
  );
}

String sha256Convert(List<int> bytes) => sha256.convert(bytes).toString();

/// Deletes any `NNN.mp3` files in [dir] whose chapter number exceeds [limit].
Future<void> _pruneExtraChapters(Directory dir, int limit) async {
  if (!await dir.exists()) return;
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final name = p.basenameWithoutExtension(entity.path);
    final chapter = int.tryParse(name);
    if (chapter == null) continue;
    if (chapter > limit) {
      await entity.delete();
    }
  }
}
