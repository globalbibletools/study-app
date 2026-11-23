import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/edit_book_list_view_model.dart';

void main() {
  test('starts with a defensive copy of the supplied order', () {
    final initial = [3, 1, 2];
    final viewModel = EditBookListViewModel(initial);

    initial.add(4);

    expect(viewModel.bookIds, [3, 1, 2]);
  });

  test('available books are the unselected books in canonical order', () {
    final viewModel = EditBookListViewModel(
      [5, 2],
      allBookIds: [1, 2, 3, 4, 5],
    );

    expect(viewModel.availableBookIds, [1, 3, 4]);
  });

  test('removing a book keeps the remaining order', () {
    final viewModel = EditBookListViewModel([3, 1, 2], allBookIds: [1, 2, 3]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.removeBook(1);

    expect(viewModel.bookIds, [3, 2]);
    expect(notifications, 1);
  });

  test('adding an unselected book appends it to the end', () {
    final viewModel = EditBookListViewModel([3, 1], allBookIds: [1, 2, 3]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.addBook(2);

    expect(viewModel.bookIds, [3, 1, 2]);
    expect(notifications, 1);
  });

  test('adding ignores books already in the list', () {
    final viewModel = EditBookListViewModel([1, 2], allBookIds: [1, 2, 3]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.addBook(2);

    expect(viewModel.bookIds, [1, 2]);
    expect(notifications, 0);
  });

  test('moving a book updates the order', () {
    final viewModel = EditBookListViewModel([1, 2, 3], allBookIds: [1, 2, 3]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.moveBook(2, 0);

    expect(viewModel.bookIds, [3, 1, 2]);
    expect(notifications, 1);
  });

  test('moving to the same position is a no-op', () {
    final viewModel = EditBookListViewModel([1, 2, 3], allBookIds: [1, 2, 3]);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.moveBook(1, 1);

    expect(viewModel.bookIds, [1, 2, 3]);
    expect(notifications, 0);
  });
}
