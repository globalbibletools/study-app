import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/bible_collection.dart';
import 'package:gbt/reading_plan/ui/delete_reading_plan_confirm_dialog.dart';
import 'package:gbt/reading_plan/ui/edit_book_list_panel.dart';
import 'package:gbt/reading_plan/ui/edit_reading_plan_view_model.dart';
import 'package:gbt/reading_plan/ui/number_stepper.dart';
import 'package:gbt/reading_plan/ui/reading_plan_app_bar.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/ui/navigation/view_model_navigation.dart';

class EditReadingPlanPanel extends StatefulWidget {
  final EditReadingPlanViewModel viewModel;

  const EditReadingPlanPanel({super.key, required this.viewModel});

  static Future<void> navigateToNew(BuildContext context, String name) {
    return pushViewModelPage<EditReadingPlanViewModel, void>(
      context: context,
      create: () => EditReadingPlanViewModel.createNew(name),
      buildView: (viewModel) => EditReadingPlanPanel(viewModel: viewModel),
    );
  }

  static Future<void> navigateToExisting(BuildContext context, int planId) {
    return pushViewModelPage<EditReadingPlanViewModel, void>(
      context: context,
      create: () => EditReadingPlanViewModel.createExisting(planId),
      buildView: (viewModel) => EditReadingPlanPanel(viewModel: viewModel),
    );
  }

  @override
  State<EditReadingPlanPanel> createState() => _EditReadingPlanPanelState();
}

class _EditReadingPlanPanelState extends State<EditReadingPlanPanel> {
  late final EditReadingPlanViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel;
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
            _appBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  spacing: 16,
                  children: [
                    Expanded(child: _content()),
                    _addPlanButton(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _appBar() {
    final l10n = AppLocalizations.of(context)!;
    return ReadingPlanAppBar(
      title: Text(
        viewModel.isExisting ? l10n.editReadingPlan : l10n.createReadingPlan,
      ),
      onBack: () => Navigator.of(context).pop(),
      actions: [
        if (viewModel.isExisting)
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: l10n.deleteReadingPlan,
            onPressed: _confirmDelete,
          ),
      ],
    );
  }

  Widget _content() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          _section(l10n.name.toUpperCase(), _planHeader()),
          _section(l10n.books.toUpperCase(), _collectionSelector()),
          _section(l10n.goal.toUpperCase(), _goalLine(l10n)),
          _estimatedCompletion(),
        ],
      ),
    );
  }

  Widget _section(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [_sectionLabel(label), child],
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
    final l10n = AppLocalizations.of(context)!;

    return Row(
      spacing: 8,
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
                  return viewModel.collectionOptions.map((collection) {
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _collectionLabel(l10n, collection),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList();
                },
                items: viewModel.collectionOptions.map((collection) {
                  return DropdownMenuItem<BibleCollection>(
                    value: collection,
                    child: Text(
                      _collectionLabel(l10n, collection),
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
        IconButton(
          key: const Key('edit-book-list'),
          icon: const Icon(Icons.edit_outlined),
          tooltip: AppLocalizations.of(context)!.editOrder,
          onPressed: _openBookListEditor,
        ),
      ],
    );
  }

  String _collectionLabel(AppLocalizations l10n, BibleCollection collection) {
    return switch (collection) {
      BibleCollection.custom => l10n.custom,
      BibleCollection.wholeBible => l10n.wholeBible,
      BibleCollection.oldTestament => l10n.oldTestament,
      BibleCollection.newTestament => l10n.newTestament,
      BibleCollection.torah => l10n.torah,
      BibleCollection.prophets => l10n.prophets,
      BibleCollection.writings => l10n.writings,
      BibleCollection.gospels => l10n.gospels,
      BibleCollection.paulineEpistles => l10n.paulineEpistles,
      BibleCollection.psalms => l10n.bookPsalms,
    };
  }

  Future<void> _openBookListEditor() async {
    final result = await EditBookListPanel.navigateTo(
      context,
      viewModel.orderedBookIds,
    );

    if (result == null) return;
    viewModel.setBooks(result);
  }

  Widget _goalLine(AppLocalizations l10n) {
    return Row(
      spacing: 8,
      children: [
        NumberStepper(
          keyPrefix: 'goal',
          initialValue: viewModel.goalValue,
          onChanged: (value) => viewModel.setGoalValue(value.round()),
        ),
        _goalTypeDropdown(l10n),
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
          spacing: 4,
          children: [
            Text(_goalTypeLabel(l10n, viewModel.goalType), style: textStyle),
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
      spacing: 10,
      children: [
        Icon(
          Icons.calendar_today_outlined,
          color: colorScheme.onSurface,
          size: 20,
        ),
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

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: canSubmit ? _handleAddPlan : null,
        child: Text(
          viewModel.isExisting
              ? AppLocalizations.of(context)!.updateReadingPlan
              : AppLocalizations.of(context)!.addReadingPlan,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteReadingPlanConfirmDialog(planName: viewModel.name),
    );
    if (confirmed != true) return;

    await viewModel.delete();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleAddPlan() async {
    final success = await viewModel.submit();
    if (!success || !mounted) return;
    Navigator.of(context).pop();
  }
}
