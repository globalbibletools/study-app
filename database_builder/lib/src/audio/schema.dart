class AudioSchema {
  static const String tableName = 'timings';

  static const String colId = 'id';
  static const String colVerseId = 'verse_id';
  static const String colRecordingId = 'recording_id';
  static const String colStart = 'start';
  static const String colEnd = 'end';

  static const String createTable =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colId INTEGER PRIMARY KEY,
      $colVerseId INTEGER NOT NULL,
      $colRecordingId TEXT NOT NULL,
      $colStart REAL NOT NULL,
      $colEnd REAL NOT NULL
    );
  ''';

  // Create an index to speed up lookups by verse range and recording type
  static const String createIndex =
      '''
    CREATE INDEX idx_audio_lookup 
    ON $tableName ($colVerseId, $colRecordingId);
  ''';

  static const String insertTiming =
      '''
    INSERT INTO $tableName (
      $colId, $colVerseId, $colRecordingId, $colStart, $colEnd
    ) VALUES (?, ?, ?, ?, ?)
  ''';
}
