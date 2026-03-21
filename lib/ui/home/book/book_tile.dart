import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/book/book_body.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/ui/home/book/book_progress.dart';
import 'package:studyapp/services/settings/user_settings.dart';

class BookTile extends StatefulWidget {
  final int bookId;
  final String bookName;
  final VoidCallback onTap;
  final UserSettings userSettings;

  const BookTile({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.onTap,
    required this.userSettings,
  });

  @override
  State<BookTile> createState() => _BookTileState();
}

class _BookTileState extends State<BookTile> {
  bool pressed = false;
  double progress = 0.0; // default 0.0

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void didUpdateWidget(covariant BookTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final saved =
        widget.userSettings.getCurrentProgressForBook(widget.bookId) /
        BibleNavigation.getChapterCount(widget.bookId);
    setState(() {
      progress = saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),
      onTapUp: (_) => setState(() => pressed = false),
      onTapCancel: () => setState(() => pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: pressed ? 0.95 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(64),
                blurRadius: 8,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(child: BookBody(bookName: widget.bookName)),
              const SizedBox(height: 6),
              BookProgress(progress: progress),
            ],
          ),
        ),
      ),
    );
  }
}
