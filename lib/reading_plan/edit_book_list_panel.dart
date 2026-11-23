import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/reading_plan/edit_book_list_view_model.dart';
import 'package:material_ui/material_ui.dart';

class EditBookListPanel extends StatefulWidget {
  const EditBookListPanel({super.key, required this.bookIds});

  final List<int> bookIds;

  @override
  State<EditBookListPanel> createState() => _EditBookListPanelState();
}

class _EditBookListPanelState extends State<EditBookListPanel> {
  late final EditBookListViewModel viewModel;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    viewModel = EditBookListViewModel(widget.bookIds);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    viewModel.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop(viewModel.bookIds);
  }

  void _addBook(int bookId) {
    viewModel.addBook(bookId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    _scrollController
        .animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .then((_) {
          if (!mounted || !_scrollController.hasClients) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            final position = _scrollController.position;
            if (position.pixels < position.maxScrollExtent) {
              _scrollController.jumpTo(position.maxScrollExtent);
            }
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                children: [
                  _topBar(l10n),
                  const SizedBox(height: 12),
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
    const iconInset = 6.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: const Offset(-iconInset, 0),
            child: IconButton(
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.arrow_back),
              onPressed: _close,
            ),
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

    final colorScheme = Theme.of(context).colorScheme;
    final bookIds = viewModel.bookIds;
    return ReorderableListView.builder(
      scrollController: _scrollController,
      buildDefaultDragHandles: false,
      itemCount: bookIds.length,
      onReorderItem: viewModel.moveBook,
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return Material(color: Colors.transparent, elevation: 0, child: child);
      },
      itemBuilder: (context, index) {
        final bookId = bookIds[index];
        return _BookRow(
          key: ValueKey(bookId),
          index: index,
          name: bookNameFromId(context, bookId),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          trailing: IconButton(
            icon: Icon(Icons.close, color: colorScheme.error),
            tooltip: l10n.removeBook,
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => viewModel.removeBook(bookId),
          ),
        );
      },
    );
  }

  Widget _bottomBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: _addBookDropdown(l10n)),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _close,
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
            availableBookIds.isEmpty
                ? l10n.allBooksSelected(viewModel.allBookCount)
                : l10n.addBook,
            style: const TextStyle(fontSize: 16),
          ),
          items: [
            for (final bookId in availableBookIds)
              DropdownMenuItem<int>(
                value: bookId,
                child: Text(bookNameFromId(context, bookId)),
              ),
          ],
          onChanged: availableBookIds.isEmpty
              ? null
              : (bookId) {
                  if (bookId == null) return;
                  _addBook(bookId);
                },
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({
    super.key,
    required this.index,
    required this.name,
    required this.trailing,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final int index;
  final String name;
  final Widget trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: padding,
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
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
