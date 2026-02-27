import 'dart:io';
import 'dart:developer';
import 'package:sqlite3/sqlite3.dart';
import 'schema.dart';

class TimingRecord {
  int verseId;
  String recordingId;
  double start;
  double? end;

  TimingRecord({
    required this.verseId,
    required this.recordingId,
    required this.start,
    this.end,
  });
}

class AudioDatabase {
  final String outputDbName = 'audio_timings.db';
  late Database _database;
  late PreparedStatement _insertStmt;

  void init() {
    _deleteDatabase();
    print('Opening database: $outputDbName');
    _database = sqlite3.open(outputDbName);
    _createTable();
    _initPreparedStatements();
  }

  void _deleteDatabase() {
    final file = File(outputDbName);
    if (file.existsSync()) {
      log('Deleting existing database file: $outputDbName');
      file.deleteSync();
    }
  }

  void _createTable() {
    _database.execute(AudioSchema.createTable);
    _database.execute(AudioSchema.createIndex);
  }

  void _initPreparedStatements() {
    _insertStmt = _database.prepare(AudioSchema.insertTiming);
  }

  Future<void> populateTable(String csvPath) async {
    final file = File(csvPath);

    if (!file.existsSync()) {
      throw Exception('Input file not found at: $csvPath');
    }

    print('Reading CSV file: $csvPath');
    final lines = await file.readAsLines();

    if (lines.isEmpty) {
      print('CSV file is empty.');
      return;
    }

    List<TimingRecord> records = [];

    // Starting at i = 1 explicitly skips the header row
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      // We still expect 5 parts from the CSV line, even though we ignore parts[0]
      if (parts.length < 5) continue;

      try {
        // parts[0] is the CSV's ID, which we completely ignore
        final verseId = int.parse(parts[1]);
        final recordingId = parts[2];
        final start = double.parse(parts[3]);

        double? end;
        if (parts[4].isNotEmpty) {
          end = double.tryParse(parts[4]);
        }

        records.add(
          TimingRecord(
            verseId: verseId,
            recordingId: recordingId,
            start: start,
            end: end,
          ),
        );
      } catch (e) {
        log('Error parsing line $i: $line. Error: $e');
      }
    }

    // Sort records to ensure verse 2 always comes after verse 1 for the look-ahead
    records.sort((a, b) {
      int cmp = a.recordingId.compareTo(b.recordingId);
      if (cmp != 0) return cmp;
      return a.verseId.compareTo(b.verseId);
    });

    // Clean up the 'end' timings
    for (int i = 0; i < records.length; i++) {
      var current = records[i];
      TimingRecord? next;

      if (i + 1 < records.length) {
        next = records[i + 1];
      }

      // Check if the next record belongs to the same chapter file.
      // E.g., dividing 35002001 by 1000 yields 35002 (the chapter).
      bool hasNextInSameFile =
          next != null &&
          next.recordingId == current.recordingId &&
          (next.verseId ~/ 1000) == (current.verseId ~/ 1000);

      bool isEndBad = false;

      // Bad if null, 0, or before/equal to start
      if (current.end == null || current.end! <= current.start) {
        isEndBad = true;
      }
      // Bad if it overlaps into the next verse
      else if (hasNextInSameFile && current.end! > next.start) {
        isEndBad = true;
      }

      // Apply the fix
      if (isEndBad) {
        if (hasNextInSameFile) {
          current.end = next.start; // Fix using next verse start
        } else {
          current.end = null; // Last verse in file, leave open-ended
        }
      }
    }

    print('Beginning transaction...');
    _database.execute('BEGIN TRANSACTION;');

    for (var record in records) {
      _insertStmt.execute([
        record.verseId,
        record.recordingId,
        record.start,
        record.end,
      ]);
    }

    _database.execute('COMMIT;');
    print('Inserted ${records.length} cleaned audio timing records.');
  }

  void dispose() {
    _insertStmt.close();
    _database.close();
  }
}
