import 'package:flutter/foundation.dart';
import 'package:gbt/common/bible_collection.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/reading_plan/reading_plan_estimates.dart';

class EditReadingPlanViewModel extends ChangeNotifier {
  final ReadingPlanDetails readingPlan;

  final ReadingPlanService _planService;
  final BibleNavigation _bibleNavigation;

  bool _disposed = false;

  static ReadingPlanDetails defaultPlan(String name) {
    final collection = BibleCollections.collections[0];
    final plan = ReadingPlan(
      planName: name,
      createdAt: DateTime.now(),
      collectionId: collection.id,
      goalType: GoalType.verses.name,
      goalValue: 10,
      isBookmarked: false,
    );
    return ReadingPlanDetails(plan, [
      for (int i = 0; i < collection.books.length; i++)
        // Not persisted until the plan is saved.
        ReadingPlanBook(
          readingPlanId: 0,
          bookId: collection.books[i],
          ord: i + 1,
        ),
    ]);
  }

  EditReadingPlanViewModel(ReadingPlanDetails readingPlan)
    : this.withDependencies(
        readingPlan,
        planService: getIt<ReadingPlanService>(),
        bibleNavigation: getIt<BibleNavigation>(),
      );

  EditReadingPlanViewModel.withDependencies(
    this.readingPlan, {
    required ReadingPlanService planService,
    required BibleNavigation bibleNavigation,
  }) : _planService = planService,
       _bibleNavigation = bibleNavigation {
    final plan = readingPlan.readingPlan;
    _orderedBookIds = [for (final book in readingPlan.books) book.bookId];
    _selectedCollection =
        BibleCollections.matchingCollection(_orderedBookIds) ??
        BibleCollections.custom;
    _goalType = readingPlan.dailyGoal.type;
    _goalValue = readingPlan.dailyGoal.value;
    _name = plan.planName;
  }

  bool get isExisting => readingPlan.readingPlan.id != null;

  late String _name;
  String get name => _name;
  void setPlanName(String value) {
    if (_name == value) return;
    _name = value;
    notifyListeners();
  }

  late BibleCollection _selectedCollection;
  BibleCollection get selectedCollection => _selectedCollection;
  void selectCollection(BibleCollection collection) {
    if (collection.id == BibleCollections.custom.id) return;
    if (_selectedCollection.id == collection.id &&
        listEquals(_orderedBookIds, collection.books)) {
      return;
    }
    _selectedCollection = collection;
    _orderedBookIds = List<int>.of(collection.books);
    notifyListeners();
  }

  late List<int> _orderedBookIds;
  List<int> get orderedBookIds => List.unmodifiable(_orderedBookIds);
  Set<int> get selectedBookIds => _orderedBookIds.toSet();

  void setSelectedBooks(Set<int> books) {
    final reordered = [
      for (final bookId in _orderedBookIds)
        if (books.contains(bookId)) bookId,
    ];
    final added = [
      for (final bookId in books)
        if (!_orderedBookIds.contains(bookId)) bookId,
    ]..sort();
    reordered.addAll(added);
    if (listEquals(reordered, _orderedBookIds)) return;

    _orderedBookIds = reordered;
    _syncSelectedCollection();
    notifyListeners();
  }

  void setBookOrder(List<int> bookIds) {
    final seen = <int>{};
    final ordered = [
      for (final bookId in bookIds)
        if (seen.add(bookId)) bookId,
    ];
    if (listEquals(ordered, _orderedBookIds)) return;

    _orderedBookIds = ordered;
    _syncSelectedCollection();
    notifyListeners();
  }

  void _syncSelectedCollection() {
    _selectedCollection =
        BibleCollections.matchingCollection(_orderedBookIds) ??
        BibleCollections.custom;
  }

  late GoalType _goalType;
  GoalType get goalType => _goalType;
  void setGoalType(GoalType type) {
    if (_goalType == type) return;
    _goalType = type;
    notifyListeners();
  }

  late int _goalValue;
  int get goalValue => _goalValue;

  void setGoalValue(int value) {
    if (value < 1 || _goalValue == value) return;
    _goalValue = value;
    notifyListeners();
  }

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  int get selectedBookCount => _orderedBookIds.length;
  int get collectionBookCount => _selectedCollection.books.length;

  bool get canSubmit =>
      !_isSubmitting && _name.trim().isNotEmpty && _orderedBookIds.isNotEmpty;

  int get estimatedDays {
    int totalVerses = 0;
    for (int bookId in _orderedBookIds) {
      totalVerses += _bibleNavigation.getTotalVerseCount(bookId);
    }

    return ReadingPlanEstimates.daysFor(
      remainingVerses: totalVerses,
      goalType: _goalType,
      goalValue: _goalValue,
    ).clamp(1, 100000);
  }

  double get estimatedMonths =>
      ReadingPlanEstimates.monthsForDays(estimatedDays);

  DateTime get estimatedCompletionDate =>
      DateTime.now().add(Duration(days: estimatedDays));

  Future<bool> submit() async {
    if (!canSubmit) return false;

    _isSubmitting = true;
    notifyListeners();

    try {
      await _planService.saveReadingPlan(
        existingPlanDetails: readingPlan.readingPlan.id != null
            ? readingPlan
            : null,
        planName: _name,
        collectionId: _selectedCollection.id,
        goalType: _goalType,
        goalValue: _goalValue,
        selectedBookIds: _orderedBookIds.toSet(),
        orderedBookIds: _orderedBookIds,
      );
      return true;
    } finally {
      _isSubmitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> delete() async {
    final planId = readingPlan.readingPlan.id;
    if (planId == null) return;
    await _planService.deleteReadingPlan(planId);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
