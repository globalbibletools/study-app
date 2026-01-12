import 'package:flutter/material.dart';

class VerseListItem extends StatefulWidget {
  const VerseListItem({
    super.key,
    required this.verseContentFuture,
    required this.formattedReference,
    required this.textDirection,
  });

  final Future<TextSpan> verseContentFuture;
  final String formattedReference;
  final TextDirection textDirection;

  @override
  State<VerseListItem> createState() => _VerseListItemState();
}

// AutomaticKeepAliveClientMixin prevents the scrollview not to stutter when
// scrolling back. This is due to the future builder. If we can provide a non-
// future builder solution later, that would be better.  Maybe by fetching in
// batches or by sqlite3 synchronous fetches.
class _VerseListItemState extends State<VerseListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important: required by the mixin

    return FutureBuilder<TextSpan>(
      future: widget.verseContentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            title: Text(widget.formattedReference),
            subtitle: Text('Error loading verse: ${snapshot.error}'),
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          final verse = snapshot.data!;
          return ListTile(
            title: Text(
              widget.formattedReference,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            subtitle: Text.rich(verse, textDirection: widget.textDirection),
          );
        } else {
          // This placeholder shows while the future is loading.
          return const SizedBox(height: 75);
        }
      },
    );
  }
}
