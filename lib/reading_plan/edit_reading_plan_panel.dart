import 'package:material_ui/material_ui.dart';
import 'package:gbt/common/bible_collection.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/reading_plan/delete_reading_plan_confirm_dialog.dart';
import 'package:gbt/reading_plan/edit_book_list_panel.dart';
import 'package:gbt/reading_plan/edit_reading_plan_view_model.dart';
import 'package:gbt/reading_plan/goal_value_editor.dart';

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
        return Column(
          children: [
            _topTitle(),
            const SizedBox(height: 12),
            Expanded(child: _content()),
            const SizedBox(height: 16),
            _addPlanButton(),
          ],
        );
      },
    );
  }

  Widget _topTitle() {
    final l10n = AppLocalizations.of(context)!;
    const iconInset = 6.0;
    final iconStyle = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: const Offset(-iconInset, 0),
            child: IconButton(
              style: iconStyle,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        Text(
          viewModel.isExisting ? l10n.editReadingPlan : l10n.createReadingPlan,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        if (viewModel.isExisting)
          Align(
            alignment: Alignment.centerRight,
            child: Transform.translate(
              offset: const Offset(iconInset, 0),
              child: IconButton(
                style: iconStyle,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                tooltip: l10n.deleteReadingPlan,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => DeleteReadingPlanConfirmDialog(
                      planName: widget.planDetails.readingPlan.planName,
                    ),
                  );
                  if (confirmed == true) {
                    await viewModel.delete();
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  }
                },
              ),
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
          _sectionLabel(l10n.name.toUpperCase()),
          const SizedBox(height: 8),
          _planHeader(),
          const SizedBox(height: 20),
          _sectionLabel(l10n.books.toUpperCase()),
          const SizedBox(height: 8),
          _collectionSelector(),
          const SizedBox(height: 20),
          _sectionLabel(l10n.goal.toUpperCase()),
          const SizedBox(height: 8),
          _goalLine(l10n),
          const SizedBox(height: 24),
          _estimatedCompletion(),
        ],
      ),
    );
  }

  Widget _planHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: TextFormField(
        initialValue: viewModel.name,
        onChanged: viewModel.setPlanName,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
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
    final collections = [
      ...BibleCollections.collections,
      if (viewModel.selectedCollection.id == BibleCollections.custom.id)
        BibleCollections.custom,
    ];

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BibleCollection>(
                value: viewModel.selectedCollection,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: colorScheme.onSurface,
                ),
                borderRadius: BorderRadius.circular(14),
                dropdownColor: colorScheme.surfaceContainerLow,
                selectedItemBuilder: (context) {
                  return collections.map((collection) {
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        BibleCollections.localizedName(context, collection),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList();
                },
                items: collections.map((collection) {
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
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const Key('edit-book-list'),
          icon: const Icon(Icons.edit_outlined),
          tooltip: AppLocalizations.of(context)!.editOrder,
          onPressed: _openBookListEditor,
        ),
      ],
    );
  }

  Future<void> _openBookListEditor() async {
    final result = await Navigator.of(context).push<List<int>>(
      MaterialPageRoute(
        builder: (_) => EditBookListPanel(bookIds: viewModel.orderedBookIds),
      ),
    );

    if (result == null) return;
    viewModel.setBookOrder(result);
  }

  Widget _goalLine(AppLocalizations l10n) {
    return Row(
      children: [
        GoalValueEditor(
          initialValue: viewModel.goalValue,
          onChanged: viewModel.setGoalValue,
        ),
        const SizedBox(width: 12),
        _goalTypeDropdown(l10n),
        const SizedBox(width: 6),
        Text(
          l10n.perDay,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _goalTypeDropdown(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);

    return PopupMenuButton<GoalType>(
      key: const Key('goal-type-dropdown'),
      tooltip: l10n.goalType,
      initialValue: viewModel.goalType,
      onSelected: viewModel.setGoalType,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        for (final type in GoalType.values)
          PopupMenuItem<GoalType>(
            value: type,
            child: Text(_goalTypeLabel(l10n, type), style: textStyle),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_goalTypeLabel(l10n, viewModel.goalType), style: textStyle),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              color: colorScheme.onSurface,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _goalTypeLabel(AppLocalizations l10n, GoalType type) =>
      type == GoalType.minutes ? l10n.minutes : l10n.verses;

  Widget _estimatedCompletion() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final completionDate = viewModel.estimatedCompletionDate;
    final date =
        '${l10n.months(completionDate.month.toString())} '
        '${completionDate.day}, ${completionDate.year}';

    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          color: colorScheme.onSurface,
          size: 20,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            '${l10n.daysCount(viewModel.estimatedDays)} ($date)',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _addPlanButton() {
    final canSubmit = viewModel.canSubmit;
    final isSubmitting = viewModel.isSubmitting;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: canSubmit ? _handleAddPlan : null,
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                viewModel.isExisting
                    ? AppLocalizations.of(context)!.updateReadingPlan
                    : AppLocalizations.of(context)!.addReadingPlan,
                style: const TextStyle(fontWeight: FontWeight.bold),
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
