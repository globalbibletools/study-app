import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:gbt/asyncutils/serial_queue.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/reading_plan/bible_collection.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/services/service_locator.dart';

class EditReadingPlanViewModel extends ChangeNotifier {
  final _planService = getIt<ReadingPlanService>();
  final _bibleNavigation = getIt<BibleNavigation>();

  EditReadingPlanViewModel._({
    required int? planId,
    required String planName,
    required GoalType goalType,
    required int goalValue,
    required List<int> bookIds,
  }) : _planId = planId {
    _name = planName;
    _goalType = goalType;
    _goalValue = goalValue;
    _orderedBookIds = List.of(bookIds);
    _customBookIds = selectedCollection == BibleCollection.custom
        ? List.of(_orderedBookIds)
        : [];
  }

  static Future<EditReadingPlanViewModel> createNew(String name) async {
    return EditReadingPlanViewModel._(
      planId: null,
      planName: name,
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: BibleCollection.wholeBible.books,
    );
  }

  static Future<EditReadingPlanViewModel> createExisting(int planId) async {
    final queries = getIt<ReadingPlanQueries>();
    final config = await queries.getPlanConfig(planId);
    if (config == null) {
      throw StateError('Reading plan not found');
    }

    return EditReadingPlanViewModel._(
      planId: config.planId,
      planName: config.planName,
      goalType: config.dailyGoal.type,
      goalValue: config.dailyGoal.value,
      bookIds: config.bookIds,
    );
  }

  // Plan basics

  final int? _planId;
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

  BibleCollection get selectedCollection =>
      BibleCollection.matchingCollection(_orderedBookIds);
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
      if (preset == BibleCollection.custom) {
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

  final _commands = SerialQueue();

  bool get canSubmit => _name.trim().isNotEmpty && _orderedBookIds.isNotEmpty;

  Future<bool> submit() async {
    try {
      return await _commands.runUnique('submit', () async {
        if (!canSubmit) return false;

        await _planService.saveReadingPlan(
          planId: _planId,
          planName: _name,
          goalType: _goalType,
          goalValue: _goalValue,
          bookIds: _orderedBookIds,
        );
        return true;
      });
    } on InFlightError {
      // A save is already running; that call owns the outcome.
      return false;
    }
  }

  Future<void> delete() {
    return _commands.runCoalesced('delete', () async {
      final planId = _planId;
      if (planId == null) return;

      try {
        await _planService.deleteReadingPlan(planId);
      } on StateError catch (error) {
        // A plan the user already deleted is gone: the intent is satisfied.
        if (!error.message.toString().startsWith('Reading plan not found')) {
          rethrow;
        }
      }
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
    unawaited(() async {
      await _commands.close();

      super.dispose();
    }());
  }
}
