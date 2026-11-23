import 'package:flutter/foundation.dart';
import 'package:gbt/common/bible_collection.dart';

class EditBookListViewModel extends ChangeNotifier {
  EditBookListViewModel(List<int> initialBookIds, {List<int>? allBookIds})
    : _allBookIds = List.unmodifiable(allBookIds ?? BibleCollections.allBooks),
      _bookIds = _dedupe(initialBookIds);

  final List<int> _allBookIds;
  List<int> _bookIds;

  static List<int> _dedupe(List<int> bookIds) {
    final seen = <int>{};
    return [
      for (final bookId in bookIds)
        if (seen.add(bookId)) bookId,
    ];
  }

  List<int> get bookIds => List.unmodifiable(_bookIds);

  bool get isEmpty => _bookIds.isEmpty;

  List<int> get availableBookIds => [
    for (final bookId in _allBookIds)
      if (!_bookIds.contains(bookId)) bookId,
  ];

  int get allBookCount => _allBookIds.length;

  void removeBook(int bookId) {
    if (!_bookIds.remove(bookId)) return;
    notifyListeners();
  }

  void addBook(int bookId) {
    if (!_allBookIds.contains(bookId) || _bookIds.contains(bookId)) return;
    _bookIds = [..._bookIds, bookId];
    notifyListeners();
  }

  void moveBook(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _bookIds.length) return;
    if (newIndex < 0 || newIndex >= _bookIds.length) return;
    if (oldIndex == newIndex) return;

    final reordered = List<int>.of(_bookIds);
    final bookId = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, bookId);
    _bookIds = reordered;
    notifyListeners();
  }
}
