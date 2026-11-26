import 'package:gbt/reading_plan/data_access/backup_rows.dart';
import 'package:sqflite/sqflite.dart';

class SessionLogRepository {
  SessionLogRepository(this._database);

  final DatabaseExecutor _database;

  Future<int> append(SessionLogEntry entry) async {
    final id = await _database.insert('rs_log', entry.toMap()..remove('id'));
    return id;
  }

  Future<List<Map<String, Object?>>> exportAll() async {
    return _database.query('rs_log', orderBy: 'id');
  }

  static const _logColumns = [
    'id',
    'rs_session_id',
    'reading_plan_id',
    'book_id',
    'chapter',
    'verse',
    'date_time',
  ];

  Future<void> importAll(Object? rows) async {
    final logRows = parseBackupRows(rows, 'rs_log');

    await _database.delete('rs_log');

    final batch = _database.batch();
    for (final row in logRows) {
      batch.insert('rs_log', pickBackupColumns(row, _logColumns));
    }
    await batch.commit(noResult: true);
  }

  Future<int> remove(int id) {
    return _database.delete('rs_log', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteForPlanId(int readingPlanId) {
    return _database.delete(
      'rs_log',
      where: 'reading_plan_id = ?',
      whereArgs: [readingPlanId],
    );
  }

  Future<List<SessionLogEntry>> listForSession(int sessionId) async {
    final rows = await _database.query(
      'rs_log',
      where: 'rs_session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'book_id, chapter, verse',
    );

    return [for (final row in rows) SessionLogEntry.fromMap(row)];
  }

  Future<SessionLogEntry?> getVerseLogForSession(
    int sessionId,
    int bookId,
    int chapter,
    int verse,
  ) async {
    final rows = await _database.query(
      'rs_log',
      where: 'rs_session_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [sessionId, bookId, chapter, verse],
      orderBy: 'id',
      limit: 1,
    );

    return rows.isEmpty ? null : SessionLogEntry.fromMap(rows.first);
  }
}

class SessionLogEntry {
  const SessionLogEntry({
    this.id,
    required this.sessionId,
    required this.readingPlanId,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.dateTime,
  });

  final int? id;
  final int sessionId;
  final int readingPlanId;
  final int bookId;
  final int chapter;
  final int verse;
  final DateTime dateTime;

  factory SessionLogEntry.fromMap(Map<String, Object?> map) {
    return SessionLogEntry(
      id: map['id'] as int?,
      sessionId: map['rs_session_id'] as int,
      readingPlanId: map['reading_plan_id'] as int,
      bookId: map['book_id'] as int,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      dateTime: DateTime.parse(map['date_time'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'rs_session_id': sessionId,
      'reading_plan_id': readingPlanId,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'date_time': dateTime.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SessionLogEntry &&
        other.id == id &&
        other.sessionId == sessionId &&
        other.readingPlanId == readingPlanId &&
        other.bookId == bookId &&
        other.chapter == chapter &&
        other.verse == verse &&
        other.dateTime == dateTime;
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    readingPlanId,
    bookId,
    chapter,
    verse,
    dateTime,
  );
}
