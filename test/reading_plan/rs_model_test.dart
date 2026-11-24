import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/rs_model.dart';

void main() {
  group('RsSession', () {
    test('round-trips the manual flag and defaults it to false', () {
      final start = DateTime.parse('2026-11-20T08:00:00.000');
      final end = DateTime.parse('2026-11-20T08:15:00.000');

      final manual = RsSession.fromMap({
        'id': 4,
        'rs_date': '2026-11-20T00:00:00.000',
        'start_time': start.toIso8601String(),
        'end_time': end.toIso8601String(),
        'read_seconds': 900,
        'verses': 7,
        'reading_plan_id': 2,
        'is_manual': 1,
      });

      expect(manual.isManual, isTrue);
      expect(manual.readSeconds, 900);
      expect(manual.verses, 7);
      expect(manual.toMap()['is_manual'], 1);
      expect(manual.copyWith(isManual: false).isManual, isFalse);

      final legacy = RsSession.fromMap({
        'id': 5,
        'rs_date': '2026-11-20T00:00:00.000',
        'start_time': start.toIso8601String(),
        'end_time': end.toIso8601String(),
        'read_seconds': 300,
        'verses': 2,
        'reading_plan_id': 2,
      });

      expect(legacy.isManual, isFalse);
      expect(legacy.toMap()['is_manual'], 0);
    });
  });

  group('RsVerseState', () {
    test('round-trips values and defaults missing fields', () {
      final lastRead = DateTime.parse('2026-05-01T10:15:30.000');
      final state = RsVerseState.fromMap({
        'reading_plan_id': 2,
        'book_id': 19,
        'chapter': 23,
        'verse': 6,
        'read_count': 3,
        'last_read': lastRead.toIso8601String(),
      });

      expect(state.readingPlanId, 2);
      expect(state.bookId, 19);
      expect(state.chapter, 23);
      expect(state.verse, 6);
      expect(state.readCount, 3);
      expect(state.lastRead, lastRead);

      expect(state.toMap(), {
        'reading_plan_id': 2,
        'book_id': 19,
        'chapter': 23,
        'verse': 6,
        'read_count': 3,
        'last_read': lastRead.toIso8601String(),
      });

      final empty = RsVerseState.fromMap({
        'reading_plan_id': 1,
        'book_id': 1,
        'chapter': 1,
        'verse': 1,
      });

      expect(empty.readCount, 0);
      expect(empty.lastRead, isNull);
    });
  });

  group('BookProgress', () {
    test('derives completion from verse totals', () {
      const complete = BookProgress(
        bookId: 63,
        totalVerses: 13,
        versesRead: 13,
      );
      const empty = BookProgress(bookId: 67, totalVerses: 0, versesRead: 0);

      expect(complete.isComplete, isTrue);
      expect(empty.isComplete, isFalse);
    });
  });

  test('DailyGoal reads legacy and named goal strings', () {
    expect(DailyGoal.fromStored('M', 15).type, GoalType.minutes);
    expect(DailyGoal.fromStored('V', 25).type, GoalType.verses);
    expect(DailyGoal.fromStored('minutes', 20).type, GoalType.minutes);
    expect(DailyGoal.fromStored('verses', 30).type, GoalType.verses);
  });
}
