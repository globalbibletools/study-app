import 'package:sqflite/sqflite.dart';

class VerseStateRepository {
  VerseStateRepository(Database database) : _database = database;

  final DatabaseExecutor _database;

  Future<void> markRead(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse, {
    DateTime? timestamp,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    await db.rawUpdate(
      'UPDATE rs_verse_state '
      'SET read_count = read_count + 1, last_read = ? '
      'WHERE reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      [
        (timestamp ?? DateTime.now()).toIso8601String(),
        readingPlanId,
        bookId,
        chapter,
        verse,
      ],
    );
  }

  Future<void> unmarkRead(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    await db.rawUpdate(
      'UPDATE rs_verse_state '
      'SET read_count = MAX(read_count - 1, 0), '
      '    last_read = CASE WHEN read_count <= 1 THEN NULL ELSE last_read END '
      'WHERE reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      [readingPlanId, bookId, chapter, verse],
    );
  }

  Future<int> deleteForPlanId(int readingPlanId, {DatabaseExecutor? executor}) {
    final db = executor ?? _database;

    return db.delete(
      'rs_verse_state',
      where: 'reading_plan_id = ?',
      whereArgs: [readingPlanId],
    );
  }

  Future<void> bulkInsert(
    int readingPlanId,
    Map<(int, int), List<int>> inventory, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;

    final batch = db.batch();
    for (final entry in inventory.entries) {
      final (bookId, chapter) = entry.key;
      for (final verse in entry.value) {
        batch.rawInsert(
          'INSERT OR IGNORE INTO rs_verse_state '
          '(reading_plan_id, book_id, chapter, verse, read_count, last_read) '
          'VALUES (?, ?, ?, ?, 0, NULL)',
          [readingPlanId, bookId, chapter, verse],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<int?> getReadCount(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final rows = await db.query(
      'rs_verse_state',
      columns: ['read_count'],
      where:
          'reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [readingPlanId, bookId, chapter, verse],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first['read_count'] as int;
  }

  Future<bool> isBookComplete(
    int readingPlanId,
    int bookId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total_verses, '
      '       SUM(CASE WHEN read_count > 0 THEN 1 ELSE 0 END) AS read_verses '
      'FROM rs_verse_state v '
      'WHERE v.reading_plan_id = ? AND v.book_id = ?',
      [readingPlanId, bookId],
    );

    final total = rows.first['total_verses'] as int? ?? 0;
    final read = rows.first['read_verses'] as int? ?? 0;
    return total > 0 && read == total;
  }
}
