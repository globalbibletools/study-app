import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/ui/edit_book_list_view_model.dart';

void main() {
  List<int> availableExcept(Set<int> selected) => [
    for (final bookId in EditBookListViewModel.allBookIds)
      if (!selected.contains(bookId)) bookId,
  ];

  test('starts with a defensive copy of the supplied order', () {
    final initial = [3, 1, 2];
    final viewModel = EditBookListViewModel(initial);

    initial.add(4);

    expect(viewModel.bookIds, [3, 1, 2]);
  });

  test('available books are the unselected books in canonical order', () {
    final viewModel = EditBookListViewModel([5, 2]);

    expect(viewModel.availableBookIds, availableExcept({5, 2}));
  });

  test('removing a book restores it to availability', () {
    final viewModel = EditBookListViewModel([3, 1, 2]);

    viewModel.removeBook(1);

    expect(viewModel.bookIds, [3, 2]);
    expect(viewModel.availableBookIds, availableExcept({3, 2}));
  });

  test('adding a book removes it from availability', () {
    final viewModel = EditBookListViewModel([3, 1]);

    viewModel.addBook(2);

    expect(viewModel.availableBookIds, availableExcept({3, 1, 2}));
  });

  test('adding ignores books already in the list', () {
    final viewModel = EditBookListViewModel([1, 2]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.addBook(2);

    expect(viewModel.bookIds, [1, 2]);
    expect(notifications, 0);
  });

  test('adding ignores unknown books', () {
    final viewModel = EditBookListViewModel([1, 2]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.addBook(999);

    expect(viewModel.bookIds, [1, 2]);
    expect(notifications, 0);
  });

  test('removing a book that is not selected is a no-op', () {
    final viewModel = EditBookListViewModel([1, 2]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.removeBook(3);

    expect(viewModel.bookIds, [1, 2]);
    expect(notifications, 0);
  });

  test('moving to the same position is a no-op', () {
    final viewModel = EditBookListViewModel([1, 2, 3]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.moveBook(1, 1);

    expect(viewModel.bookIds, [1, 2, 3]);
    expect(notifications, 0);
  });

  test('moving outside the list is a no-op', () {
    final viewModel = EditBookListViewModel([1, 2, 3]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.moveBook(-1, 0);
    viewModel.moveBook(0, -1);
    viewModel.moveBook(3, 0);
    viewModel.moveBook(0, 3);

    expect(viewModel.bookIds, [1, 2, 3]);
    expect(notifications, 0);
  });

  test('clearing books empties the list and restores availability', () {
    final viewModel = EditBookListViewModel([3, 1, 2]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.clearBooks();

    expect(viewModel.bookIds, isEmpty);
    expect(viewModel.isEmpty, isTrue);
    expect(viewModel.availableBookIds, availableExcept({}));
    expect(notifications, 1);
  });

  test('clearing an empty list is a no-op', () {
    final viewModel = EditBookListViewModel(const []);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.clearBooks();

    expect(viewModel.bookIds, isEmpty);
    expect(notifications, 0);
  });

  test('hasChanges is false initially', () {
    final viewModel = EditBookListViewModel([3, 1, 2]);

    expect(viewModel.hasChanges, isFalse);
  });

  test('adding a book is a change', () {
    final viewModel = EditBookListViewModel([3, 1]);

    viewModel.addBook(2);

    expect(viewModel.hasChanges, isTrue);
  });

  test('removing a book is a change', () {
    final viewModel = EditBookListViewModel([3, 1, 2]);

    viewModel.removeBook(1);

    expect(viewModel.hasChanges, isTrue);
  });

  test('reordering books is a change', () {
    final viewModel = EditBookListViewModel([3, 1, 2]);

    viewModel.moveBook(0, 2);

    expect(viewModel.hasChanges, isTrue);
  });

  test('clearing books is a change', () {
    final viewModel = EditBookListViewModel([3, 1, 2]);

    viewModel.clearBooks();

    expect(viewModel.hasChanges, isTrue);
  });

  test('reverting changes clears hasChanges', () {
    final viewModel = EditBookListViewModel([1, 2, 3]);

    viewModel.addBook(4);
    viewModel.removeBook(4);
    expect(viewModel.hasChanges, isFalse);

    viewModel.moveBook(0, 1);
    expect(viewModel.hasChanges, isTrue);
    viewModel.moveBook(1, 0);
    expect(viewModel.hasChanges, isFalse);

    viewModel.clearBooks();
    expect(viewModel.hasChanges, isTrue);
    viewModel.addBook(1);
    viewModel.addBook(2);
    viewModel.addBook(3);
    expect(viewModel.hasChanges, isFalse);
  });
}
