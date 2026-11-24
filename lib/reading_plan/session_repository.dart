import 'package:sqflite/sqflite.dart';

class SessionRepository {
  SessionRepository(this._database);

  final Database _database;

  Future<Session> commit(Session session, {DatabaseExecutor? executor}) async {
    final db = executor ?? _database;
    if (session.id == null) {
      final id = await db.insert('rs_session', session.toMap()..remove('id'));
      return session.copyWith(id: id);
    }

    await db.update(
      'rs_session',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
    return session;
  }

  Future<int> delete(int id, {DatabaseExecutor? executor}) {
    final db = executor ?? _database;

    return db.delete('rs_session', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteForPlanId(int readingPlanId, {DatabaseExecutor? executor}) {
    final db = executor ?? _database;

    return db.delete(
      'rs_session',
      where: 'reading_plan_id = ?',
      whereArgs: [readingPlanId],
    );
  }

  Future<Session?> getById(int id, {DatabaseExecutor? executor}) async {
    final db = executor ?? _database;
    final rows = await db.query(
      'rs_session',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : Session.fromMap(rows.first);
  }

  Future<int> countForDate(
    DateTime date,
    int readingPlanId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final result = await db.rawQuery(
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
}
