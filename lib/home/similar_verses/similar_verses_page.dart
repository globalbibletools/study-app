import 'package:flutter/material.dart';
import 'package:studyapp/common/reference.dart';

import 'similar_verse_manager.dart';

class SimilarVersesPage extends StatefulWidget {
  const SimilarVersesPage({super.key, required this.strongsCode});

  final String strongsCode;

  @override
  State<SimilarVersesPage> createState() => _SimilarVersesPageState();
}

class _SimilarVersesPageState extends State<SimilarVersesPage> {
  final manager = SimilarVerseManager();

  @override
  void initState() {
    super.initState();
    manager.init(widget.strongsCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: Text(
        //   '${widget.strongsCode.word} (${widget.strongsCode.strongsNumber})',
        //   style: TextStyle(
        //     fontFamily: fontFamily,
        //   ),
        // ),
      ),
      body: ValueListenableBuilder<List<Reference>>(
        valueListenable: manager.similarVersesNotifier,
        builder: (context, verseList, child) {
          return ListView.builder(
            itemCount: verseList.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Center(
                  child: Text(
                    '${verseList.length}',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.color?.withAlpha(100),
                    ),
                  ),
                );
              }
              final referenceIndex = index - 1;
              final reference = verseList[referenceIndex];
              final formattedReference = _formatReference(reference);
              return FutureBuilder<TextSpan>(
                future: manager.getVerseContent(
                  reference,
                  widget.strongsCode,
                  Theme.of(context).colorScheme.primary,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ListTile(
                      title: Text(formattedReference),
                      subtitle: Text('Error loading verse: ${snapshot.error}'),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.done) {
                    final verse = snapshot.data!;
                    return ListTile(
                      title: Text(formattedReference),
                      subtitle: Text.rich(verse),
                    );
                  } else {
                    // Giving the widget a height ensures that the
                    // ListView.builder will not try to build the
                    // every item in the list just because they all
                    // theoretically fit with a zero height.
                    return const SizedBox(height: 50);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatReference(Reference reference) {
    return '${reference.bookId} ${reference.chapter}:${reference.verse}';
  }
}
