import 'package:gbt/common/reference.dart';
import 'package:sqflite/sqflite.dart';

typedef VerseInventoryProvider =
    Future<Map<(int, int), List<int>>> Function(Set<int> bookIds);

class VerseStateRepository {
  VerseStateRepository(
    this._database, {
    required VerseInventoryProvider verseInventoryProvider,
  }) : _verseInventoryProvider = verseInventoryProvider;

  final DatabaseExecutor _database;
  final VerseInventoryProvider _verseInventoryProvider;

  Future<void> markRead(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse, {
    DateTime? timestamp,
  }) async {
    await _database.rawUpdate(
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
    int verse,
  ) async {
    await _database.rawUpdate(
      'UPDATE rs_verse_state '
      'SET read_count = MAX(read_count - 1, 0), '
      '    last_read = CASE WHEN read_count <= 1 THEN NULL ELSE last_read END '
      'WHERE reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      [readingPlanId, bookId, chapter, verse],
    );
  }

  Future<int> deleteForPlanId(int readingPlanId) {
    return _database.delete(
      'rs_verse_state',
      where: 'reading_plan_id = ?',
      whereArgs: [readingPlanId],
    );
  }

  Future<int> deleteAll() {
    return _database.delete('rs_verse_state');
  }

  Future<void> backfillFromLog() async {
    await _database.rawInsert(
      'INSERT OR REPLACE INTO rs_verse_state '
      '(reading_plan_id, book_id, chapter, verse, read_count, last_read) '
      'SELECT reading_plan_id, book_id, chapter, verse, '
      '       COUNT(*), MAX(date_time) '
      'FROM rs_log '
      'GROUP BY reading_plan_id, book_id, chapter, verse',
    );
  }

  Future<void> materializeAll() async {
    final plans = await _database.query('reading_plan', columns: ['id']);
    for (final plan in plans) {
      await materialize(plan['id'] as int);
    }
  }

  Future<void> materialize(int planId, {Set<int>? bookIds}) async {
    final rows = await _database.query(
      'reading_plan_book',
      columns: ['book_id'],
      where: 'reading_plan_id = ?',
      whereArgs: [planId],
    );
    final planBookIds = rows.map((row) => row['book_id'] as int).toSet();
    final targetBookIds = bookIds == null
        ? planBookIds
        : planBookIds.intersection(bookIds);
    if (targetBookIds.isEmpty) return;

    final inventory = await _verseInventoryProvider(targetBookIds);
    if (inventory.isEmpty) return;

    final batch = _database.batch();
    for (final entry in inventory.entries) {
      final (bookId, chapter) = entry.key;
      for (final verse in entry.value) {
        batch.rawInsert(
          'INSERT OR IGNORE INTO rs_verse_state '
          '(reading_plan_id, book_id, chapter, verse, read_count, last_read) '
          'VALUES (?, ?, ?, ?, 0, NULL)',
          [planId, bookId, chapter, verse],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<int?> getReadCount(
    int readingPlanId,
    int bookId,
    int chapter,
    int verse,
  ) async {
    final rows = await _database.query(
      'rs_verse_state',
      columns: ['read_count'],
      where:
          'reading_plan_id = ? AND book_id = ? AND chapter = ? AND verse = ?',
      whereArgs: [readingPlanId, bookId, chapter, verse],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first['read_count'] as int;
  }

  Future<Map<int, BookStats>> getBookStats(int readingPlanId) async {
    final rows = await _database.rawQuery(
      'SELECT v.book_id AS book_id, '
      '       COUNT(*) AS total_verses, '
      '       SUM(CASE WHEN v.read_count > 0 THEN 1 ELSE 0 END) AS verses_read, '
      '       MAX(v.last_read) AS last_read, '
      '       (SELECT v2.chapter '
      '        FROM rs_verse_state v2 '
      '        WHERE v2.reading_plan_id = v.reading_plan_id '
      '          AND v2.book_id = v.book_id '
      '          AND v2.read_count = 0 '
      '        ORDER BY v2.chapter, v2.verse '
      '        LIMIT 1) AS resume_chapter, '
      '       (SELECT v2.verse '
      '        FROM rs_verse_state v2 '
      '        WHERE v2.reading_plan_id = v.reading_plan_id '
      '          AND v2.book_id = v.book_id '
      '          AND v2.read_count = 0 '
      '        ORDER BY v2.chapter, v2.verse '
      '        LIMIT 1) AS resume_verse '
      'FROM rs_verse_state v '
      'JOIN reading_plan_book b '
      '  ON b.reading_plan_id = v.reading_plan_id '
      ' AND b.book_id = v.book_id '
      'WHERE v.reading_plan_id = ? '
      'GROUP BY v.book_id',
      [readingPlanId],
    );

    return {
      for (final row in rows)
        row['book_id'] as int: BookStats(
          bookId: row['book_id'] as int,
          totalVerses: row['total_verses'] as int,
          versesRead: row['verses_read'] as int? ?? 0,
          lastRead: row['last_read'] != null
              ? DateTime.parse(row['last_read'] as String)
              : null,
          resumePosition: row['resume_chapter'] == null
              ? null
              : Reference(
                  bookId: row['book_id'] as int,
                  chapter: row['resume_chapter'] as int,
                  verse: row['resume_verse'] as int,
                ),
        ),
    };
  }

  Future<bool> isBookComplete(int readingPlanId, int bookId) async {
    final rows = await _database.rawQuery(
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

class BookStats {
  const BookStats({
    required this.bookId,
    required this.totalVerses,
    required this.versesRead,
    required this.lastRead,
    this.resumePosition,
  });

  final int bookId;
  final int totalVerses;
  final int versesRead;
  final DateTime? lastRead;
  final Reference? resumePosition;

  bool get isComplete => totalVerses > 0 && versesRead == totalVerses;
}
