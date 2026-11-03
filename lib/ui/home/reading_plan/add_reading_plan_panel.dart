import 'package:flutter/material.dart';
import 'package:gbt/common/bible_collection.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/ui/home/keypad/numeric_keypad.dart';
import 'package:gbt/ui/home/reading_plan/add_reading_plan_panel_manager.dart';

class AddReadingPlanPanel extends StatefulWidget {
  final ReadingPlanDetails? planDetails;
  const AddReadingPlanPanel({super.key, this.planDetails});

  @override
  State<AddReadingPlanPanel> createState() => _AddReadingPlanPanelState();
}

class _AddReadingPlanPanelState extends State<AddReadingPlanPanel> {
  static const _allDigits = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
  static const _firstDigits = {1, 2, 3, 4, 5, 6, 7, 8, 9};

  late final TextEditingController _planNameController;
  late final AddReadingPlanPanelManager manager;
  late BibleCollection _selectedCollection;
  late Set<int> _selectedBookIds;
  late GoalType _goalType;
  late int _goalValue;

  bool _isEditingValue = false;
  String _valueInput = '';

  bool _isSubmitting = false;
  bool _defaultPlanNameApplied = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.planDetails;
    manager = AddReadingPlanPanelManager(existing);

    if (existing != null) {
      _selectedCollection = BibleCollections.fromId(
        existing.readingPlan.collectionId,
      );
      _selectedBookIds = existing.books.map((x) => x.bookId).toSet();

      _goalType = existing.dailyGoal.type;
      _goalValue = existing.dailyGoal.value;
      _planNameController = TextEditingController(
        text: existing.readingPlan.planName,
      );
    } else {
      _selectedCollection = BibleCollections.collections[0];
      _selectedBookIds = _selectedCollection.books.toSet();
      _goalType = GoalType.verses;
      _goalValue = 10;
      _planNameController = TextEditingController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.planDetails == null && !_defaultPlanNameApplied) {
      _planNameController.text = AppLocalizations.of(
        context,
      )!.defaultReadingPlanName;
      _defaultPlanNameApplied = true;
    }
  }

  String _booksSummary(AppLocalizations l10n) {
    final total = _selectedCollection.books.length;
    final selected = _selectedBookIds.length;
    if (selected == total) {
      return l10n.allBooksSelected(total);
    }
    return l10n.booksSelected(selected, total);
  }

  int get _estimatedDays {
    int totalVerses = 0;
    for (int bookId in _selectedBookIds) {
      totalVerses += BibleNavigation.getTotalVerseCount(bookId);
    }

    if (_goalType == GoalType.verses) {
      return (totalVerses / _goalValue).ceil().clamp(1, 100000);
    }
    final totalMinutes = (totalVerses / 5).ceil();
    return (totalMinutes / _goalValue).ceil().clamp(1, 100000);
  }

  String _estimatedMonthsLabel(AppLocalizations l10n) {
    final months = _estimatedDays / 30.44;
    return l10n.monthsCount(months.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _planNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    final panel = Container(
      height: screenHeight * (_isEditingValue ? 0.55 : 0.85),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 16),
          _topTitle(),
          const SizedBox(height: 12),
          Expanded(child: _content()),
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              panel,
              if (_isEditingValue)
                Material(
                  elevation: 16,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: NumericKeypad(
                    isLastInput: true,
                    enabledDigits: _valueInput.isEmpty
                        ? _firstDigits
                        : _allDigits,
                    onDigit: _handleDigit,
                    onBackspace: _handleBackspace,
                    onSubmit: _finishEditingValue,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _topTitle() {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Text(
          l10n.readingPlans,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _content() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _planHeader(),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 20),
          _sectionLabel(l10n.collection.toUpperCase()),
          const SizedBox(height: 8),
          _collectionSelector(),
          const SizedBox(height: 20),
          _sectionLabel(l10n.books.toUpperCase()),
          const SizedBox(height: 8),
          _booksSelector(),
          const SizedBox(height: 20),
          _sectionLabel(l10n.goal.toUpperCase()),
          const SizedBox(height: 8),
          _goalTypeToggle(),
          const SizedBox(height: 20),
          Center(child: _buildEditableValue()),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _goalType == GoalType.minutes
                  ? l10n.minutesPerDay.toUpperCase()
                  : l10n.versesPerDay.toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel(l10n.estimatedCompletion.toUpperCase()),
          const SizedBox(height: 8),
          _estimatedCompletion(),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _addPlanButton(),
        ],
      ),
    );
  }

  Widget _planHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _planNameController,
      style: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintText: AppLocalizations.of(context)!.planName,
        suffixIcon: Icon(Icons.edit, size: 18, color: colorScheme.primary),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 28,
          minHeight: 28,
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _collectionSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BibleCollection>(
          value: _selectedCollection,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurface),
          borderRadius: BorderRadius.circular(14),
          dropdownColor: colorScheme.surfaceContainerLow,
          selectedItemBuilder: (context) {
            return BibleCollections.collections.map((collection) {
              return Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    BibleCollections.localizedName(context, collection),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList();
          },
          items: BibleCollections.collections.map((collection) {
            return DropdownMenuItem<BibleCollection>(
              value: collection,
              child: Text(
                BibleCollections.localizedName(context, collection),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (collection) {
            if (collection == null) return;
            setState(() {
              _selectedCollection = collection;
              // Default to all books in the newly chosen collection.
              _selectedBookIds = collection.books.toSet();
            });
          },
        ),
      ),
    );
  }

  Widget _booksSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openBookPicker,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.format_list_bulleted, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _booksSummary(l10n),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurface),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBookPicker() async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _BookPickerSheet(
          collection: _selectedCollection,
          initiallySelected: _selectedBookIds,
        );
      },
    );

    if (result != null) {
      setState(() => _selectedBookIds = result);
    }
  }

  /// Verses/Minutes toggle, styled like SetDailyGoalView's goal-type toggle.
  Widget _goalTypeToggle() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _buildToggleButton(
            title: l10n.verses,
            selected: _goalType == GoalType.verses,
            onTap: () {
              setState(() {
                _goalType = GoalType.verses;
                _isEditingValue = false;
                _valueInput = '';
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildToggleButton(
            title: l10n.minutes,
            selected: _goalType == GoalType.minutes,
            onTap: () {
              setState(() {
                _goalType = GoalType.minutes;
                _isEditingValue = false;
                _valueInput = '';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(title)),
      ),
    );
  }

  /// Value stepper + tap-to-edit field, taken from SetDailyGoalView.
  Widget _buildEditableValue() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(
          icon: Icons.remove,
          onTap: () {
            if (_goalValue > 1) {
              setState(() {
                _isEditingValue = false;
                _valueInput = '';
                _goalValue--;
              });
            }
          },
        ),
        const SizedBox(width: 30),
        _editableValueField(),
        const SizedBox(width: 30),
        _circleButton(
          icon: Icons.add,
          onTap: () {
            setState(() {
              _isEditingValue = false;
              _valueInput = '';
              _goalValue++;
            });
          },
        ),
      ],
    );
  }

  Widget _editableValueField() {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = _valueInput.isEmpty
        ? _goalValue.toString()
        : _valueInput;

    return GestureDetector(
      onTap: _startEditingValue,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 110,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _isEditingValue
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            displayValue,
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w300,
              color: _isEditingValue ? colorScheme.primary : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  void _startEditingValue() {
    if (_isEditingValue) return;

    setState(() {
      _isEditingValue = true;
      _valueInput = '';
    });
  }

  void _finishEditingValue() {
    setState(() {
      _isEditingValue = false;
      _valueInput = '';
    });
  }

  void _handleDigit(int digit) {
    if (_valueInput.isEmpty && digit == 0) return;

    final nextInput = _valueInput + digit.toString();
    final nextValue = int.tryParse(nextInput);
    if (nextValue == null || nextValue < 1) return;

    setState(() {
      _valueInput = nextInput;
      _goalValue = nextValue;
    });
  }

  void _handleBackspace() {
    if (_valueInput.isEmpty) {
      _finishEditingValue();
      return;
    }

    final nextInput = _valueInput.substring(0, _valueInput.length - 1);
    final nextValue = int.tryParse(nextInput);

    setState(() {
      _valueInput = nextInput;
      if (nextValue != null && nextValue > 0) {
        _goalValue = nextValue;
      }
    });
  }

  Widget _estimatedCompletion() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          color: colorScheme.onSurface,
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(
          '${l10n.daysCount(_estimatedDays)} ',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        Text(
          _estimatedMonthsLabel(l10n),
          style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _addPlanButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _planNameController,
      builder: (context, nameValue, _) {
        final canSubmit =
            !_isSubmitting &&
            _selectedBookIds.isNotEmpty &&
            nameValue.text.trim().isNotEmpty;

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: canSubmit
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: canSubmit ? _handleAddPlan : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSubmitting)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.add,
                    color: canSubmit
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                const SizedBox(width: 8),
                Text(
                  widget.planDetails != null
                      ? AppLocalizations.of(context)!.updateReadingPlan
                      : AppLocalizations.of(context)!.addReadingPlan,
                  style: TextStyle(
                    color: canSubmit
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleAddPlan() async {
    setState(() => _isSubmitting = true);

    try {
      await manager.addReadingPlan(
        _planNameController.text,
        _selectedCollection.id,
        _goalType,
        _goalValue,
        _selectedBookIds,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _BookPickerSheet extends StatefulWidget {
  final BibleCollection collection;
  final Set<int> initiallySelected;

  const _BookPickerSheet({
    required this.collection,
    required this.initiallySelected,
  });

  @override
  State<_BookPickerSheet> createState() => _BookPickerSheetState();
}

class _BookPickerSheetState extends State<_BookPickerSheet> {
  late Set<int> _selected = {...widget.initiallySelected};

  bool get _allSelected => _selected.length == widget.collection.books.length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      top: false,
      child: Container(
        height: screenHeight * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    BibleCollections.localizedName(context, widget.collection),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selected = _allSelected
                          ? {}
                          : widget.collection.books.toSet();
                    });
                  },
                  child: Text(_allSelected ? l10n.deselectAll : l10n.selectAll),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: widget.collection.books.length,
                itemBuilder: (context, index) {
                  final bookId = widget.collection.books[index];
                  final selected = _selected.contains(bookId);
                  return CheckboxListTile(
                    value: selected,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      bookNameFromId(context, bookId),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    activeColor: colorScheme.primary,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selected.add(bookId);
                        } else {
                          _selected.remove(bookId);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(_selected),
                child: Text(
                  _selected.isEmpty
                      ? l10n.selectAtLeastOneBook
                      : l10n.doneSelected(_selected.length),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
