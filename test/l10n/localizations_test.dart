import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('every supported locale builds with its localizations', (
    tester,
  ) async {
    const changelogTitles = {
      'ar': 'سجل التغييرات',
      'en': 'Changelog',
      'es': 'Novedades',
      'fr': 'Nouveautés',
      'pt': 'Novidades',
    };

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Text(AppLocalizations.of(context)!.changelog),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(changelogTitles[locale.languageCode]!), findsOneWidget);
    }
  });
}
