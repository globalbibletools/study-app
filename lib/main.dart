import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/bible/bible_database.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/lexicon/database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';
import 'package:studyapp/ui/home/home.dart';

import 'app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  await getIt<UserSettings>().init();
  await getIt<HebrewGreekDatabase>().init();
  await getIt<GlossService>().init();
  // TODO: Maybe we should delay loading the lexicon until it is needed.
  await getIt<LexiconsDatabase>().init();
  // await getIt<BibleDatabase>().init();
  runApp(const GbtStudyApp());
}

class GbtStudyApp extends StatefulWidget {
  const GbtStudyApp({super.key});

  @override
  State<GbtStudyApp> createState() => _GbtStudyAppState();
}

class _GbtStudyAppState extends State<GbtStudyApp> {
  final appState = getIt<AppState>();

  @override
  void initState() {
    super.initState();
    appState.init();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, child) {
        return MaterialApp(
          title: 'Global Bible Tools',
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: appState.locale,
          theme: appTheme,
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
