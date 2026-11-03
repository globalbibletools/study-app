import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/services/reading_session/rs_model.dart';

void main() {
  group('RsBookProgress.fromMap', () {
    test('parses normal map correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 1,
        'book_id': 1,
        'chapter': 2,
        'verse': 3,
        'chapters_read': 4,
        'verses_read': 5,
        'updated_at': now.toIso8601String(),
        'reading_plan_id': 1,
      };

      final progress = RsBookProgress.fromMap(map);
      expect(progress.id, 1);
      expect(progress.bookId, 1);
      expect(progress.chapter, 2);
      expect(progress.verse, 3);
      expect(progress.chaptersRead, 4);
      expect(progress.versesRead, 5);
      expect(progress.updatedAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(progress.readingPlanId, 1);
    });

    test('defaults missing optional fields gracefully', () {
      final now = DateTime.now();
      final map = {
        'id': 1,
        'book_id': 1,
        'chapter': 1,
        'verse': 1,
        'chapters_read': 0,
        'updated_at': now.toIso8601String(),
      };

      final progress = RsBookProgress.fromMap(map);
      expect(progress.versesRead, 0);
      expect(progress.readingPlanId, 1);
    });
  });
}
