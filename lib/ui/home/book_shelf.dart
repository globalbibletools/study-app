import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/appbar/drawer.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/ui/home/book/book_tile.dart';
import 'package:studyapp/ui/home/home.dart';
import 'package:studyapp/services/settings/user_settings.dart';
import 'home_manager.dart';
import 'package:studyapp/services/service_locator.dart';

class BookShelf extends StatefulWidget {
  const BookShelf({super.key});

  @override
  State<BookShelf> createState() => _BookShelfState();
}

class _BookShelfState extends State<BookShelf> {
  final manager = HomeManager();

  final _settings = getIt<UserSettings>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      manager.checkOnboarding(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager.init();
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      drawer: AppDrawer(
        onSettingsClosed: () => manager.notifySettingsChanged(),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle(l10n.oldTestament),
            _booksGrid(context, 1, 39),

            const SizedBox(height: 24),

            _sectionTitle(l10n.newTestament),
            _booksGrid(context, 40, 66),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _booksGrid(BuildContext context, int start, int end) {
    final books = List.generate(end - start + 1, (i) => start + i);
    final brightness = Theme.of(context).brightness;

    return GridView.builder(
      key: ValueKey(brightness),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2 / 3,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final bookId = books[index];
        final bookName = bookNameFromId(context, bookId);

        return BookTile(
          bookId: bookId,
          bookName: bookName,
          userSettings: _settings,
          onTap: () async {
            manager.onBookSelected(context, bookId);
            manager.onChapterSelected(_settings.getCurrentProgressForBook(bookId));
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(manager: manager),
              ),
            );
            setState(() {});
          },
        );
      },
    );
  }
}
