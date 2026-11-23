import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/reading_plan/discard_book_list_changes_dialog.dart';
import 'package:gbt/reading_plan/edit_book_list_view_model.dart';
import 'package:material_ui/material_ui.dart';

typedef NavigateToEditBookListRoute =
    Future<List<int>?> Function(BuildContext context, List<int> bookIds);

class EditBookListPanel extends StatefulWidget {
  const EditBookListPanel({super.key, required this.viewModel});

  final EditBookListViewModel viewModel;

  static Future<List<int>?> navigateTo(
    BuildContext context,
    List<int> bookIds,
  ) async {
    final viewModel = EditBookListViewModel(bookIds);

    try {
      return await Navigator.of(context).push<List<int>>(
        MaterialPageRoute(
          builder: (_) => EditBookListPanel(viewModel: viewModel),
        ),
      );
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }
  }

  @override
  State<EditBookListPanel> createState() => _EditBookListPanelState();
}

class _EditBookListPanelState extends State<EditBookListPanel> {
  late final EditBookListViewModel viewModel;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel;
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    viewModel.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(viewModel.bookIds);
  }

  Future<void> _cancel() async {
    if (!viewModel.hasChanges) {
      Navigator.of(context).pop(null);
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => const DiscardBookListChangesDialog(),
    );
    if (discard != true || !mounted) return;

    Navigator.of(context).pop(null);
  }

  void _addBook(int? bookId) {
    if (bookId == null || viewModel.bookIds.contains(bookId)) return;
    viewModel.addBook(bookId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancel();
      },
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                spacing: 16,
                children: [
                  _topBar(l10n),
                  Expanded(child: _bookList(l10n)),
                  _bottomBar(l10n),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar(AppLocalizations l10n) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: const Offset(-6, 0),
            child: IconButton(
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.arrow_back),
              onPressed: _cancel,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            key: const Key('clear-books'),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.clear_all),
            tooltip: l10n.clearBooks,
            onPressed: viewModel.clearBooks,
          ),
        ),
        Text(
          l10n.customizeBooks,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _bookList(AppLocalizations l10n) {
    if (viewModel.isEmpty) {
      return Center(child: Text(l10n.selectAtLeastOneBook));
    }

    final bookIds = viewModel.bookIds;
    return ReorderableListView(
      scrollController: _scrollController,
      buildDefaultDragHandles: false,
      // Allows us to scroll to the end of the list when adding a new book.
      scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
      onReorderItem: viewModel.moveBook,
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return Material(color: Colors.transparent, elevation: 0, child: child);
      },
      // We eager render so that we can scroll to the end when adding a new book.
      children: [
        for (var index = 0; index < bookIds.length; index++)
          _bookRow(index, bookIds[index]),
      ],
    );
  }

  Widget _bookRow(int index, int bookId) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: ValueKey(bookId),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle_rounded),
          ),
          Expanded(
            child: Text(
              bookNameFromId(context, bookId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.error),
            tooltip: l10n.removeBook,
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => viewModel.removeBook(bookId),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        spacing: 8,
        children: [
          Expanded(child: _addBookDropdown(l10n)),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _save,
            child: Text(
              l10n.save,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addBookDropdown(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final availableBookIds = viewModel.availableBookIds;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: null,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurface),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: colorScheme.surfaceContainerLow,
          hint: Text(
            availableBookIds.isEmpty ? l10n.allBooksSelected : l10n.addBook,
            style: const TextStyle(fontSize: 16),
          ),
          items: [
            for (final bookId in availableBookIds)
              DropdownMenuItem<int>(
                value: bookId,
                child: Text(bookNameFromId(context, bookId)),
              ),
          ],
          onChanged: availableBookIds.isEmpty ? null : _addBook,
        ),
      ),
    );
  }
}
