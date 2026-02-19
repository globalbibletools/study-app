import 'package:flutter/material.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'swipeable_selector.dart';

class BookSelector extends StatefulWidget {
  final String currentBookName;
  final int currentBookId;
  final bool isActive;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final Function(int) onChanged;
  final Function(int) onSubmitted;
  final VoidCallback onCancel;

  const BookSelector({
    super.key,
    required this.currentBookName,
    required this.currentBookId,
    required this.isActive,
    required this.focusNode,
    required this.onTap,
    required this.onChanged,
    required this.onSubmitted,
    required this.onCancel,
  });

  @override
  State<BookSelector> createState() => _BookSelectorState();
}

class _BookSelectorState extends State<BookSelector> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<_BookSearchModel> _allBooks = [];
  List<_BookSearchModel> _filteredBooks = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBookData();
  }

  @override
  void didUpdateWidget(covariant BookSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _controller.clear();
      _removeOverlay();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _showOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !widget.focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _loadBookData() {
    _allBooks = List.generate(66, (index) {
      final id = index + 1;
      final name = bookNameFromId(context, id);

      return _BookSearchModel(
        id: id,
        displayName: name,
        searchKey: _SearchUtilities.normalize(name),
      );
    });
    _filteredBooks = List.from(_allBooks);
  }

  void _onTextChanged() {
    final input = _SearchUtilities.normalize(_controller.text);
    setState(() {
      _filteredBooks = _filter(input);
    });
    _overlayEntry?.markNeedsBuild();

    if (_filteredBooks.length == 1) {
      final match = _filteredBooks.first;
      _selectBook(match.id);
    }
  }

  List<_BookSearchModel> _filter(String normalizedInput) {
    if (normalizedInput.isEmpty) return _allBooks;
    int minScore = 999999;
    List<_BookSearchModel> bestMatches = [];

    for (var book in _allBooks) {
      final searchKey = book.searchKey;
      if (!searchKey.startsWith(normalizedInput[0])) continue;
      int currentScore = 0;
      int lastIndex = -1;
      bool isMatch = true;

      for (int i = 0; i < normalizedInput.length; i++) {
        final char = normalizedInput[i];
        final index = searchKey.indexOf(char, lastIndex + 1);
        if (index == -1) {
          isMatch = false;
          break;
        }
        currentScore += index;
        lastIndex = index;
      }

      if (isMatch) {
        if (currentScore < minScore) {
          minScore = currentScore;
          bestMatches = [book];
        } else if (currentScore == minScore) {
          bestMatches.add(book);
        }
      }
    }
    return bestMatches;
  }

  void _selectBook(int id) {
    _removeOverlay();
    _controller.clear();
    widget.onSubmitted(id);
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = _filteredBooks[index];
                  return ListTile(
                    title: Text(book.displayName),
                    onTap: () => _selectBook(book.id),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: widget.isActive
          ? SizedBox(
              width: 100,
              child: TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (_filteredBooks.isNotEmpty) {
                    _selectBook(_filteredBooks.first.id);
                  } else {
                    widget.onCancel();
                  }
                },
              ),
            )
          : SwipeableSelectorButton(
              label: widget.currentBookName,
              onTap: widget.onTap,
              enableSwipe: true,
              onPeekNext: () {
                if (widget.currentBookId >= 66) return null;
                return bookNameFromId(context, widget.currentBookId + 1);
              },
              onNextInvoked: () => widget.onChanged(widget.currentBookId + 1),
              onPeekPrevious: () {
                if (widget.currentBookId <= 1) return null;
                return bookNameFromId(context, widget.currentBookId - 1);
              },
              onPreviousInvoked: () =>
                  widget.onChanged(widget.currentBookId - 1),
            ),
    );
  }
}

class _BookSearchModel {
  final int id;
  final String displayName;
  final String searchKey;

  _BookSearchModel({
    required this.id,
    required this.displayName,
    required this.searchKey,
  });
}

class _SearchUtilities {
  static final _combiningMarks = RegExp(r'[\u0300-\u036f]');

  static String normalize(String input) {
    if (input.isEmpty) return '';
    String normalized = unorm.nfd(input);
    normalized = normalized.replaceAll(_combiningMarks, '');
    normalized = normalized.toLowerCase();
    return normalized;
  }
}
