import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:gbt/common/bible_collection.dart';

class EditBookListViewModel extends ChangeNotifier {
  EditBookListViewModel(List<int> initialBookIds)
    : _bookIds = List.of(initialBookIds),
      _initialBookIds = List.of(initialBookIds) {
    _availableBookIds = _availableFor(_bookIds);
  }

  static final List<int> allBookIds = List.unmodifiable(
    BibleCollections.allBooks,
  );

  List<int> _bookIds;
  UnmodifiableListView<int> get bookIds => UnmodifiableListView(_bookIds);
  bool get isEmpty => _bookIds.isEmpty;

  final List<int> _initialBookIds;
  bool get hasChanges => !listEquals(_bookIds, _initialBookIds);

  late List<int> _availableBookIds;
  UnmodifiableListView<int> get availableBookIds =>
      UnmodifiableListView(_availableBookIds);

  static List<int> _availableFor(List<int> selectedBookIds) => [
    for (final bookId in allBookIds)
      if (!selectedBookIds.contains(bookId)) bookId,
  ];

  void _updateBookIds(List<int> newBookIds) {
    _bookIds = newBookIds;
    _availableBookIds = _availableFor(_bookIds);
    notifyListeners();
  }

  void removeBook(int bookId) {
    final updatedList = List<int>.of(_bookIds);
    if (!updatedList.remove(bookId)) return;

    _updateBookIds(updatedList);
  }

  void addBook(int bookId) {
    if (!allBookIds.contains(bookId) || _bookIds.contains(bookId)) return;

    _updateBookIds([..._bookIds, bookId]);
  }

  void clearBooks() {
    if (_bookIds.isEmpty) return;

    _updateBookIds(const []);
  }

  void moveBook(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _bookIds.length) return;
    if (newIndex < 0 || newIndex >= _bookIds.length) return;
    if (oldIndex == newIndex) return;

    final updatedList = List<int>.of(_bookIds);
    final bookId = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, bookId);

    _bookIds = updatedList;
    notifyListeners();
  }
}
