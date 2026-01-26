import 'package:flutter/material.dart';
import 'package:studyapp/ui/about/about.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/download/download_manager_page.dart';
import 'package:studyapp/ui/search/search.dart';
import 'package:studyapp/ui/settings/settings_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onSettingsClosed});

  final VoidCallback onSettingsClosed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Center(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.settings),
              leading: Icon(Icons.settings_outlined),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
                onSettingsClosed();
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.search),
              leading: Icon(Icons.search),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchPage()),
                );
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.downloads),
              leading: const Icon(Icons.download),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DownloadManagerPage(),
                  ),
                );
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.about),
              leading: Icon(Icons.info_outline),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
