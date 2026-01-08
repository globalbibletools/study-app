import 'dart:io';
import 'dart:developer';
import 'package:sqlite3/sqlite3.dart';
import 'schema.dart';

class AudioDatabase {
  final String inputCsvPath = 'lib/src/audio/data/timings.csv';
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

  Future<void> populateTable() async {
    final file = File(inputCsvPath);

    if (!file.existsSync()) {
      throw Exception('Input file not found at: $inputCsvPath');
    }

    print('Reading CSV file...');
    final lines = await file.readAsLines();

    if (lines.isEmpty) {
      print('CSV file is empty.');
      return;
    }

    print('Beginning transaction...');
    _database.execute('BEGIN TRANSACTION;');

    int count = 0;

    // Skip the header row (i=1 instead of 0) if the first row is headers
    // The example provided: id,verse_id,recording_id,start,end
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // CSV format: id,verse_id,recording_id,start,end
      // Example: 115535,01001001,HEB,12.528,18.463
      final parts = line.split(',');

      if (parts.length < 5) {
        log('Skipping malformed line $i: $line');
        continue;
      }

      try {
        final id = int.parse(parts[0]);
        final verseId = int.parse(parts[1]);
        final recordingId = parts[2];
        final start = double.parse(parts[3]);
        // Handle "end" having potential newline chars or being 0
        final end = double.parse(parts[4]);

        _insertStmt.execute([id, verseId, recordingId, start, end]);
        count++;
      } catch (e) {
        log('Error parsing line $i: $line. Error: $e');
      }
    }

    _database.execute('COMMIT;');
    print('Inserted $count audio timing records.');
  }

  void dispose() {
    _insertStmt.dispose();
    _database.dispose();
  }
}
