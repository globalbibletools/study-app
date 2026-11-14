import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/services/reading_session/rs_model.dart';

void main() {
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

  group('RsBookStats', () {
    test('derives completion from verse totals', () {
      final complete = RsBookStats(
        bookId: 63,
        totalVerses: 13,
        versesRead: 13,
        lastRead: DateTime.parse('2026-05-01T10:15:30.000'),
      );
      final empty = RsBookStats(
        bookId: 67,
        totalVerses: 0,
        versesRead: 0,
        lastRead: null,
      );

      expect(complete.isComplete, isTrue);
      expect(empty.isComplete, isFalse);
    });
  });

  test(
    'ReadingPlanDetails daily goal handles legacy and named goal strings',
    () {
      final now = DateTime.now();

      final legacyMinutes = ReadingPlanDetails(
        ReadingPlan(
          id: 1,
          planName: 'Legacy M',
          createdAt: now,
          collectionId: 1,
          goalType: 'M',
          goalValue: 15,
          isBookmarked: false,
        ),
        [],
      );
      expect(legacyMinutes.dailyGoal.type, GoalType.minutes);
      expect(legacyMinutes.dailyGoal.value, 15);

      final legacyVerses = ReadingPlanDetails(
        ReadingPlan(
          id: 2,
          planName: 'Legacy V',
          createdAt: now,
          collectionId: 1,
          goalType: 'V',
          goalValue: 25,
          isBookmarked: false,
        ),
        [],
      );
      expect(legacyVerses.dailyGoal.type, GoalType.verses);
      expect(legacyVerses.dailyGoal.value, 25);

      final namedMinutes = ReadingPlanDetails(
        ReadingPlan(
          id: 3,
          planName: 'Named Minutes',
          createdAt: now,
          collectionId: 1,
          goalType: 'minutes',
          goalValue: 20,
          isBookmarked: false,
        ),
        [],
      );
      expect(namedMinutes.dailyGoal.type, GoalType.minutes);
      expect(namedMinutes.dailyGoal.value, 20);

      final namedVerses = ReadingPlanDetails(
        ReadingPlan(
          id: 4,
          planName: 'Named Verses',
          createdAt: now,
          collectionId: 1,
          goalType: 'verses',
          goalValue: 30,
          isBookmarked: false,
        ),
        [],
      );
      expect(namedVerses.dailyGoal.type, GoalType.verses);
      expect(namedVerses.dailyGoal.value, 30);
    },
  );
}
