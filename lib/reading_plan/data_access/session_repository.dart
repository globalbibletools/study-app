import 'package:gbt/reading_plan/data_access/backup_rows.dart';
import 'package:sqflite/sqflite.dart';

class SessionRepository {
  SessionRepository(this._database);

  final DatabaseExecutor _database;

  Future<Session> commit(Session session) async {
    if (session.id == null) {
      final id = await _database.insert(
        'rs_session',
        session.toMap()..remove('id'),
      );
      return session.copyWith(id: id);
    }

    await _database.update(
      'rs_session',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
    return session;
  }

  Future<List<Map<String, Object?>>> exportAll() async {
    return _database.query('rs_session', orderBy: 'id');
  }

  static const _sessionColumns = [
    'id',
    'rs_date',
    'start_time',
    'end_time',
    'read_seconds',
    'verses',
    'reading_plan_id',
    'is_manual',
  ];

  Future<void> importAll(Object? rows) async {
    final sessionRows = parseBackupRows(rows, 'rs_session');

    await _database.delete('rs_session');

    final batch = _database.batch();
    for (final row in sessionRows) {
      batch.insert('rs_session', {
        ...pickBackupColumns(row, _sessionColumns),
        'read_seconds': _readSecondsFor(row),
        'is_manual': row['is_manual'] ?? 0,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<int> delete(int id) {
    return _database.delete('rs_session', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteForPlanId(int readingPlanId) {
    return _database.delete(
      'rs_session',
      where: 'reading_plan_id = ?',
      whereArgs: [readingPlanId],
    );
  }

  Future<Session?> getById(int id) async {
    final rows = await _database.query(
      'rs_session',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : Session.fromMap(rows.first);
  }

  Future<List<Session>> listForDate(DateTime date, int readingPlanId) async {
    final rows = await _database.query(
      'rs_session',
      where: 'date(rs_date) = date(?) AND reading_plan_id = ?',
      whereArgs: [date.toIso8601String(), readingPlanId],
      orderBy: 'start_time, id',
    );

    return [for (final row in rows) Session.fromMap(row)];
  }

  Future<int> countForDate(DateTime date, int readingPlanId) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) FROM rs_session '
      'WHERE date(rs_date) = date(?) AND reading_plan_id = ?',
      [date.toIso8601String(), readingPlanId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }
}

class Session {
  const Session({
    this.id,
    required this.rsDate,
    required this.startTime,
    this.endTime,
    this.readSeconds = 0,
    required this.verses,
    required this.readingPlanId,
    this.isManual = false,
  });

  final int? id;
  final DateTime rsDate;
  final DateTime startTime;
  final DateTime? endTime;
  final int readSeconds;
  final int verses;
  final int readingPlanId;
  final bool isManual;

  static const _undefined = Object();

  Session copyWith({
    Object? id = _undefined,
    DateTime? rsDate,
    DateTime? startTime,
    Object? endTime = _undefined,
    int? readSeconds,
    int? verses,
    int? readingPlanId,
    bool? isManual,
  }) {
    return Session(
      id: id == _undefined ? this.id : id as int?,
      rsDate: rsDate ?? this.rsDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime == _undefined ? this.endTime : endTime as DateTime?,
      readSeconds: readSeconds ?? this.readSeconds,
      verses: verses ?? this.verses,
      readingPlanId: readingPlanId ?? this.readingPlanId,
      isManual: isManual ?? this.isManual,
    );
  }

  factory Session.fromMap(Map<String, Object?> map) {
    return Session(
      id: map['id'] as int?,
      rsDate: DateTime.parse(map['rs_date'] as String),
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'] as String)
          : null,
      readSeconds: map['read_seconds'] as int? ?? 0,
      verses: map['verses'] as int,
      readingPlanId: map['reading_plan_id'] as int,
      isManual: map['is_manual'] == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'rs_date': rsDate.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'read_seconds': readSeconds,
      'verses': verses,
      'reading_plan_id': readingPlanId,
      'is_manual': isManual ? 1 : 0,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Session &&
        other.id == id &&
        other.rsDate == rsDate &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.readSeconds == readSeconds &&
        other.verses == verses &&
        other.readingPlanId == readingPlanId &&
        other.isManual == isManual;
  }

  @override
  int get hashCode => Object.hash(
    id,
    rsDate,
    startTime,
    endTime,
    readSeconds,
    verses,
    readingPlanId,
    isManual,
  );
}

int _readSecondsFor(Map<String, Object?> row) {
  final stored = row['read_seconds'];
  if (stored is num) return stored.toInt();

  final start = _parseTimestamp(row['start_time']);
  final end = _parseTimestamp(row['end_time']);
  if (start == null || end == null) return 0;

  final seconds = end.difference(start).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

DateTime? _parseTimestamp(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
