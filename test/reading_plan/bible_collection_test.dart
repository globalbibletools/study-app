import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/bible_collection.dart';

void main() {
  test('presets are in display order with custom last', () {
    expect(BibleCollection.values, [
      BibleCollection.wholeBible,
      BibleCollection.oldTestament,
      BibleCollection.newTestament,
      BibleCollection.torah,
      BibleCollection.prophets,
      BibleCollection.writings,
      BibleCollection.gospels,
      BibleCollection.paulineEpistles,
      BibleCollection.psalms,
      BibleCollection.custom,
    ]);
  });

  test('preset book lists partition the canonical book list', () {
    expect(BibleCollection.allBooks, [for (int i = 1; i <= 66; i++) i]);
    expect(BibleCollection.wholeBible.books, BibleCollection.allBooks);
    expect(BibleCollection.oldTestament.books, [
      for (int i = 1; i <= 39; i++) i,
    ]);
    expect(BibleCollection.newTestament.books, [
      for (int i = 40; i <= 66; i++) i,
    ]);
    expect(BibleCollection.custom.books, isEmpty);
  });

  test('matches a book list directly against each preset', () {
    expect(
      BibleCollection.matchingCollection(BibleCollection.torah.books),
      BibleCollection.torah,
    );
    expect(
      BibleCollection.matchingCollection(BibleCollection.psalms.books),
      BibleCollection.psalms,
    );
  });

  test('requires the same order', () {
    final reversed = BibleCollection.torah.books.reversed.toList();

    expect(BibleCollection.matchingCollection(reversed), isNull);
  });

  test('never matches custom', () {
    expect(BibleCollection.matchingCollection(const []), isNull);
    expect(BibleCollection.matchingCollection([2, 1]), isNull);
  });
}
