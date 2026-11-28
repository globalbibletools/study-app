import 'package:material_ui/material_ui.dart';
import 'package:gbt/changelog/changelog_view.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/about/about.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/ui/backup_restore_page.dart';
import 'package:gbt/ui/download/download_manager_page.dart';
import 'package:gbt/ui/search/search.dart';
import 'package:gbt/ui/settings/settings_page.dart';

class AppDrawer extends StatelessWidget {
  AppDrawer({super.key, required this.onSettingsClosed});

  final VoidCallback onSettingsClosed;
  final _resourceService = getIt<ResourceService>();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
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
              leading: ValueListenableBuilder<OutdatedResourceCounts>(
                valueListenable: _resourceService.outdatedResourceCounts,
                builder: (context, counts, _) {
                  return Badge.count(
                    count: counts.total,
                    isLabelVisible: counts.total > 0,
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.download),
                  );
                },
              ),
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
            ListTile(
              title: Text(AppLocalizations.of(context)!.changelog),
              leading: Icon(Icons.history),
              onTap: () {
                final pageContext = Scaffold.of(context).context;
                Navigator.pop(context);
                ChangelogView.navigateTo(pageContext);
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.backupRestore),
              leading: Icon(Icons.cloud_upload),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BackupRestorePage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
