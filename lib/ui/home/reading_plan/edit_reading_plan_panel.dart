import 'package:material_ui/material_ui.dart';
import 'package:gbt/common/bible_collection.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/ui/home/reading_plan/edit_reading_plan_view_model.dart';
import 'package:gbt/ui/home/reading_plan/goal_value_editor.dart';
import 'package:gbt/ui/home/reading_plan/reading_plan_panel.dart';

class EditReadingPlanPanel extends StatefulWidget {
  final ReadingPlanDetails planDetails;

  const EditReadingPlanPanel.existing(this.planDetails, {super.key});

  EditReadingPlanPanel.newPlan(String name, {super.key})
    : planDetails = EditReadingPlanViewModel.defaultPlan(name);

  @override
  State<EditReadingPlanPanel> createState() => _EditReadingPlanPanelState();
}

class _EditReadingPlanPanelState extends State<EditReadingPlanPanel> {
  late final EditReadingPlanViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = EditReadingPlanViewModel(widget.planDetails);
  }

  String _booksSummary(AppLocalizations l10n) {
    final total = viewModel.collectionBookCount;
    final selected = viewModel.selectedBookCount;
    if (selected == total) {
      return l10n.allBooksSelected(total);
    }
    return l10n.booksSelected(selected, total);
  }

  String _estimatedMonthsLabel(AppLocalizations l10n) {
    return l10n.monthsCount(viewModel.estimatedMonths.toStringAsFixed(1));
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final panel = Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _handle(),
              const SizedBox(height: 16),
              _topTitle(),
              const SizedBox(height: 12),
              Expanded(child: _content()),
            ],
          ),
        );

        return SizedBox.expand(
          child: SafeArea(
            top: false,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: panel,
            ),
          ),
        );
      },
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
        if (viewModel.isExisting)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: l10n.deleteReadingPlan,
              onPressed: () async {
                final confirmed = await confirmDeleteReadingPlan(
                  context,
                  widget.planDetails.readingPlan.planName,
                );
                if (confirmed) {
                  await viewModel.delete();
                  if (!mounted) return;
                  Navigator.of(context).pop();
                }
              },
            ),
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
              viewModel.goalType == GoalType.minutes
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
    return TextFormField(
      initialValue: viewModel.name,
      onChanged: viewModel.setPlanName,
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
          value: viewModel.selectedCollection,
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
            viewModel.selectCollection(collection);
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
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _BookPickerSheet(
          collection: viewModel.selectedCollection,
          initiallySelected: viewModel.selectedBookIds,
        );
      },
    );

    if (result != null) {
      viewModel.setSelectedBooks(result);
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
            selected: viewModel.goalType == GoalType.verses,
            onTap: () {
              viewModel.setGoalType(GoalType.verses);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildToggleButton(
            title: l10n.minutes,
            selected: viewModel.goalType == GoalType.minutes,
            onTap: () {
              viewModel.setGoalType(GoalType.minutes);
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
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableValue() {
    return GoalValueEditor(
      initialValue: viewModel.goalValue,
      onChanged: viewModel.setGoalValue,
    );
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
          '${l10n.daysCount(viewModel.estimatedDays)} ',
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
    final canSubmit = viewModel.canSubmit;
    final isSubmitting = viewModel.isSubmitting;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: canSubmit
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          foregroundColor: canSubmit
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          elevation: canSubmit ? 2 : 0,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: canSubmit ? _handleAddPlan : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSubmitting)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimary,
                ),
              )
            else
              Icon(
                Icons.check_rounded,
                color: canSubmit
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            const SizedBox(width: 8),
            Text(
              viewModel.isExisting
                  ? AppLocalizations.of(context)!.updateReadingPlan
                  : AppLocalizations.of(context)!.addReadingPlan,
              style: TextStyle(
                color: canSubmit
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddPlan() async {
    final success = await viewModel.submit();
    if (!success || !mounted) return;
    Navigator.of(context).pop();
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
