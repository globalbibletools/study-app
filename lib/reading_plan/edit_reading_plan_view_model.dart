import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/reading_plan/bible_collection.dart';
import 'package:gbt/reading_plan/reading_plan_estimates.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class EditReadingPlanViewModel extends ChangeNotifier {
  static ReadingPlanDetails defaultPlan(String name) {
    final plan = ReadingPlan(
      planName: name,
      createdAt: DateTime.now(),
      goalType: GoalType.verses.name,
      goalValue: 10,
      isBookmarked: false,
    );
    final books = BibleCollection.wholeBible.books;
    return ReadingPlanDetails(plan, [
      for (int i = 0; i < books.length; i++)
        // Not persisted until the plan is saved.
        ReadingPlanBook(readingPlanId: 0, bookId: books[i], ord: i + 1),
    ]);
  }

  EditReadingPlanViewModel._(
    this.readingPlan, {
    required ReadingPlanService planService,
    required BibleNavigation bibleNavigation,
  }) : _planService = planService,
       _bibleNavigation = bibleNavigation {
    _orderedBookIds = [for (final book in readingPlan.books) book.bookId];
    _customBookIds = selectedCollection == BibleCollection.custom
        ? List.of(_orderedBookIds)
        : [];
    _goalType = readingPlan.dailyGoal.type;
    _goalValue = readingPlan.dailyGoal.value;
    _name = readingPlan.readingPlan.planName;
  }

  static Future<EditReadingPlanViewModel> createNew(
    String name, {
    ReadingPlanService? planService,
    BibleNavigation? bibleNavigation,
  }) async {
    return EditReadingPlanViewModel._(
      defaultPlan(name),
      planService: planService ?? getIt<ReadingPlanService>(),
      bibleNavigation: bibleNavigation ?? getIt<BibleNavigation>(),
    );
  }

  static Future<EditReadingPlanViewModel> createExisting(
    int planId, {
    ReadingPlanService? planService,
    BibleNavigation? bibleNavigation,
  }) async {
    final service = planService ?? getIt<ReadingPlanService>();
    final planDetails = await service.getReadingPlanById(planId);
    if (planDetails == null) {
      throw StateError('Reading plan not found');
    }

    return EditReadingPlanViewModel._(
      planDetails,
      planService: service,
      bibleNavigation: bibleNavigation ?? getIt<BibleNavigation>(),
    );
  }

  final ReadingPlanService _planService;
  final BibleNavigation _bibleNavigation;

  // Plan basics

  final ReadingPlanDetails readingPlan;
  bool get isExisting => readingPlan.readingPlan.id != null;

  String _name = '';
  String get name => _name;
  void setPlanName(String value) {
    if (_name == value) return;
    _setState(() {
      _name = value;
    });
  }

  // Books and collection

  BibleCollection get selectedCollection =>
      BibleCollection.matchingCollection(_orderedBookIds) ??
      BibleCollection.custom;
  int get collectionBookCount => selectedCollection.books.length;

  List<BibleCollection> get collectionOptions => BibleCollection.values;

  /// The custom book list the user has created during this edit session.
  ///
  /// Kept even while a preset collection is selected, so switching back to
  /// Custom restores the previous list. It lives only as long as this view
  /// model and is never persisted unless the plan is saved with Custom
  /// selected.
  late List<int> _customBookIds;

  void selectCollection(BibleCollection collection) {
    if (collection == BibleCollection.custom) {
      if (selectedCollection == BibleCollection.custom) return;
      setBooks(List<int>.of(_customBookIds));
      return;
    }
    if (selectedCollection == collection &&
        listEquals(_orderedBookIds, collection.books)) {
      return;
    }
    setBooks(List<int>.of(collection.books));
  }

  late List<int> _orderedBookIds;
  UnmodifiableListView<int> get orderedBookIds =>
      UnmodifiableListView(_orderedBookIds);
  Set<int> get selectedBookIds => _orderedBookIds.toSet();
  int get selectedBookCount => _orderedBookIds.length;

  void setBooks(List<int> bookIds) {
    if (listEquals(bookIds, _orderedBookIds)) return;

    final preset = BibleCollection.matchingCollection(bookIds);
    _setState(() {
      _orderedBookIds = List.of(bookIds);
      if (preset == null) {
        _customBookIds = List.of(bookIds);
      }
    });
  }

  // Daily goal

  late GoalType _goalType;
  GoalType get goalType => _goalType;

  void setGoalType(GoalType type) {
    if (_goalType == type) return;
    _setState(() {
      _goalType = type;
    });
  }

  late int _goalValue;
  int get goalValue => _goalValue;

  void setGoalValue(int value) {
    if (value < 1 || _goalValue == value) return;
    _setState(() {
      _goalValue = value;
    });
  }

  // Estimates

  int get estimatedDays {
    var totalVerses = 0;
    for (final bookId in _orderedBookIds) {
      totalVerses += _bibleNavigation.getTotalVerseCount(bookId);
    }

    return ReadingPlanEstimates.daysFor(
      remainingVerses: totalVerses,
      goalType: _goalType,
      goalValue: _goalValue,
    ).clamp(1, 100000);
  }

  DateTime get estimatedCompletionDate =>
      DateTime.now().add(Duration(days: estimatedDays));

  // Save and delete

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  bool get canSubmit =>
      !_isSubmitting && _name.trim().isNotEmpty && _orderedBookIds.isNotEmpty;

  final _submitScope = CancellationScope();

  Future<bool> submit() {
    if (!canSubmit) return Future.value(false);

    return _submitScope.run((guard) async {
      _setState(() {
        _isSubmitting = true;
      });

      try {
        await guard(
          _planService.saveReadingPlan(
            existingPlanDetails: readingPlan.readingPlan.id != null
                ? readingPlan
                : null,
            planName: _name,
            goalType: _goalType,
            goalValue: _goalValue,
            selectedBookIds: _orderedBookIds.toSet(),
            orderedBookIds: List.of(_orderedBookIds),
          ),
        );
        return true;
      } finally {
        _setState(() {
          _isSubmitting = false;
        });
      }
    });
  }

  final _deleteScope = CancellationScope();

  Future<void> delete() {
    final planId = readingPlan.readingPlan.id;
    if (planId == null) return Future.value();

    return _deleteScope.run((guard) async {
      await guard(_planService.deleteReadingPlan(planId));
    });
  }

  // Lifecycle utils

  bool _disposed = false;

  void _setState(VoidCallback fn) {
    if (_disposed) return;
    fn();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _submitScope.cancelAll();
    _deleteScope.cancelAll();
    super.dispose();
  }
}
