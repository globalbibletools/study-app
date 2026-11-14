import 'package:flutter/foundation.dart';
import 'package:gbt/common/bible_collection.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class AddReadingPlanViewModel extends ChangeNotifier {
  final ReadingPlanDetails readingPlan;

  final _planService = getIt<ReadingPlanService>();
  final _bibleNavigation = getIt<BibleNavigation>();

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

  AddReadingPlanViewModel(this.readingPlan) {
    final plan = readingPlan.readingPlan;
    _selectedCollection = BibleCollections.fromId(plan.collectionId);
    _selectedBookIds = readingPlan.books.map((x) => x.bookId).toSet();
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
    if (_selectedCollection.id == collection.id) return;
    _selectedCollection = collection;
    _selectedBookIds = collection.books.toSet();
    notifyListeners();
  }

  late Set<int> _selectedBookIds;
  Set<int> get selectedBookIds => _selectedBookIds;
  void setSelectedBooks(Set<int> books) {
    if (setEquals(_selectedBookIds, books)) return;
    _selectedBookIds = {...books};
    notifyListeners();
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

  int get selectedBookCount => _selectedBookIds.length;
  int get collectionBookCount => _selectedCollection.books.length;

  bool get canSubmit =>
      !_isSubmitting && _name.trim().isNotEmpty && _selectedBookIds.isNotEmpty;

  int get estimatedDays {
    int totalVerses = 0;
    for (int bookId in _selectedBookIds) {
      totalVerses += _bibleNavigation.getTotalVerseCount(bookId);
    }

    if (_goalType == GoalType.verses) {
      return (totalVerses / _goalValue).ceil().clamp(1, 100000);
    }
    final totalMinutes = (totalVerses / 5).ceil();
    return (totalMinutes / _goalValue).ceil().clamp(1, 100000);
  }

  double get estimatedMonths => estimatedDays / 30.44;

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
        selectedBookIds: _selectedBookIds,
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
