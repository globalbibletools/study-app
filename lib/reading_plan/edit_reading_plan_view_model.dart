import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/bible_collection.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/reading_plan/reading_plan_estimates.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';

class EditReadingPlanViewModel extends ChangeNotifier {
  EditReadingPlanViewModel._(
    this._config, {
    required String planName,
    required GoalType goalType,
    required int goalValue,
    required List<int> orderedBookIds,
    required ReadingPlanService planService,
    required BibleNavigation bibleNavigation,
  }) : _planService = planService,
       _bibleNavigation = bibleNavigation {
    _planId = _config?.planId;
    _name = planName;
    _goalType = goalType;
    _goalValue = goalValue;
    _orderedBookIds = List.of(orderedBookIds);
    _selectedCollection =
        BibleCollections.matchingCollection(_orderedBookIds) ??
        BibleCollections.custom;
    _customBookIds = _selectedCollection.id == BibleCollections.custom.id
        ? List.of(_orderedBookIds)
        : [];
  }

  static Future<EditReadingPlanViewModel> createNew(
    String name, {
    ReadingPlanReadModels? readModels,
    ReadingPlanService? planService,
    BibleNavigation? bibleNavigation,
  }) async {
    final collection = BibleCollections.collections[0];
    return EditReadingPlanViewModel._(
      null,
      planName: name,
      goalType: GoalType.verses,
      goalValue: 10,
      orderedBookIds: collection.books,
      planService: planService ?? getIt<ReadingPlanService>(),
      bibleNavigation: bibleNavigation ?? getIt<BibleNavigation>(),
    );
  }

  static Future<EditReadingPlanViewModel> createExisting(
    int planId, {
    ReadingPlanReadModels? readModels,
    ReadingPlanService? planService,
    BibleNavigation? bibleNavigation,
  }) async {
    final models = readModels ?? getIt<ReadingSessionDatabase>().readModels;
    final config = await models.getPlanConfig(planId);
    if (config == null) {
      throw StateError('Reading plan not found');
    }

    return EditReadingPlanViewModel._(
      config,
      planName: config.planName,
      goalType: config.dailyGoal.type,
      goalValue: config.dailyGoal.value,
      orderedBookIds: [for (final book in config.books) book.bookId],
      planService: planService ?? getIt<ReadingPlanService>(),
      bibleNavigation: bibleNavigation ?? getIt<BibleNavigation>(),
    );
  }

  final ReadingPlanConfig? _config;
  final ReadingPlanService _planService;
  final BibleNavigation _bibleNavigation;

  int? _planId;

  // Plan basics

  bool get isExisting => _planId != null;

  String _name = '';
  String get name => _name;
  void setPlanName(String value) {
    if (_name == value) return;
    _setState(() {
      _name = value;
    });
  }

  // Books and collection

  late BibleCollection _selectedCollection;
  BibleCollection get selectedCollection => _selectedCollection;
  int get collectionBookCount => _selectedCollection.books.length;

  List<BibleCollection> get collectionOptions => [
    ...BibleCollections.collections,
    BibleCollections.custom,
  ];

  /// The custom book list the user has created during this edit session.
  ///
  /// Kept even while a preset collection is selected, so switching back to
  /// Custom restores the previous list. It lives only as long as this view
  /// model and is never persisted unless the plan is saved with Custom
  /// selected.
  late List<int> _customBookIds;

  void selectCollection(BibleCollection collection) {
    if (collection.id == BibleCollections.custom.id) {
      if (_selectedCollection.id == BibleCollections.custom.id) return;
      setBooks(List<int>.of(_customBookIds));
      return;
    }
    if (_selectedCollection.id == collection.id &&
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

    final preset = BibleCollections.matchingCollection(bookIds);
    _setState(() {
      _orderedBookIds = List.of(bookIds);
      _selectedCollection = preset ?? BibleCollections.custom;
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
            planId: _planId,
            planName: _name,
            collectionId: _selectedCollection.id,
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
    final planId = _planId;
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
