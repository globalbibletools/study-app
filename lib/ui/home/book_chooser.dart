import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';

class BookChooser extends StatefulWidget {
  const BookChooser({super.key});

  @override
  State<BookChooser> createState() => _BookChooserState();
}

class _BookChooserState extends State<BookChooser> {
  late final List<String> _oldTestamentBooks;
  late final List<String> _newTestamentBooks;

  void _initializeBooks() {
    _oldTestamentBooks = [
      AppLocalizations.of(context)!.bookGenesis,
      AppLocalizations.of(context)!.bookExodus,
      AppLocalizations.of(context)!.bookLeviticus,
      AppLocalizations.of(context)!.bookNumbers,
      AppLocalizations.of(context)!.bookDeuteronomy,
      AppLocalizations.of(context)!.bookJoshua,
      AppLocalizations.of(context)!.bookJudges,
      AppLocalizations.of(context)!.bookRuth,
      AppLocalizations.of(context)!.book1Samuel,
      AppLocalizations.of(context)!.book2Samuel,
      AppLocalizations.of(context)!.book1Kings,
      AppLocalizations.of(context)!.book2Kings,
      AppLocalizations.of(context)!.book1Chronicles,
      AppLocalizations.of(context)!.book2Chronicles,
      AppLocalizations.of(context)!.bookEzra,
      AppLocalizations.of(context)!.bookNehemiah,
      AppLocalizations.of(context)!.bookEsther,
      AppLocalizations.of(context)!.bookJob,
      AppLocalizations.of(context)!.bookPsalms,
      AppLocalizations.of(context)!.bookProverbs,
      AppLocalizations.of(context)!.bookEcclesiastes,
      AppLocalizations.of(context)!.bookSongOfSolomon,
      AppLocalizations.of(context)!.bookIsaiah,
      AppLocalizations.of(context)!.bookJeremiah,
      AppLocalizations.of(context)!.bookLamentations,
      AppLocalizations.of(context)!.bookEzekiel,
      AppLocalizations.of(context)!.bookDaniel,
      AppLocalizations.of(context)!.bookHosea,
      AppLocalizations.of(context)!.bookJoel,
      AppLocalizations.of(context)!.bookAmos,
      AppLocalizations.of(context)!.bookObadiah,
      AppLocalizations.of(context)!.bookJonah,
      AppLocalizations.of(context)!.bookMicah,
      AppLocalizations.of(context)!.bookNahum,
      AppLocalizations.of(context)!.bookHabakkuk,
      AppLocalizations.of(context)!.bookZephaniah,
      AppLocalizations.of(context)!.bookHaggai,
      AppLocalizations.of(context)!.bookZechariah,
      AppLocalizations.of(context)!.bookMalachi,
    ];

    _newTestamentBooks = [
      AppLocalizations.of(context)!.bookMatthew,
      AppLocalizations.of(context)!.bookMark,
      AppLocalizations.of(context)!.bookLuke,
      AppLocalizations.of(context)!.bookJohn,
      AppLocalizations.of(context)!.bookActs,
      AppLocalizations.of(context)!.bookRomans,
      AppLocalizations.of(context)!.book1Corinthians,
      AppLocalizations.of(context)!.book2Corinthians,
      AppLocalizations.of(context)!.bookGalatians,
      AppLocalizations.of(context)!.bookEphesians,
      AppLocalizations.of(context)!.bookPhilippians,
      AppLocalizations.of(context)!.bookColossians,
      AppLocalizations.of(context)!.book1Thessalonians,
      AppLocalizations.of(context)!.book2Thessalonians,
      AppLocalizations.of(context)!.book1Timothy,
      AppLocalizations.of(context)!.book2Timothy,
      AppLocalizations.of(context)!.bookTitus,
      AppLocalizations.of(context)!.bookPhilemon,
      AppLocalizations.of(context)!.bookHebrews,
      AppLocalizations.of(context)!.bookJames,
      AppLocalizations.of(context)!.book1Peter,
      AppLocalizations.of(context)!.book2Peter,
      AppLocalizations.of(context)!.book1John,
      AppLocalizations.of(context)!.book2John,
      AppLocalizations.of(context)!.book3John,
      AppLocalizations.of(context)!.bookJude,
      AppLocalizations.of(context)!.bookRevelation,
    ];
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeBooks();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            width: MediaQuery.of(context).size.width * 0.8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _oldTestamentBooks.length,
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop(index + 1);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6.0,
                            horizontal: 4.0,
                          ),
                          child: Text(_oldTestamentBooks[index]),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _newTestamentBooks.length,
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          Navigator.of(
                            context,
                          ).pop(_oldTestamentBooks.length + index + 1);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6.0,
                            horizontal: 4.0,
                          ),
                          child: Text(_newTestamentBooks[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
