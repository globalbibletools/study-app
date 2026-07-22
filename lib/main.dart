import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/audio/audio_database.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/lexicon/database.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/home.dart';

import 'app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  await getIt<UserSettings>().init();
  await getIt<HebrewGreekDatabase>().init();
  // TODO: Maybe we should delay loading the lexicon until it is needed.
  await getIt<LexiconsDatabase>().init();
  await getIt<BibleService>().init();
  await getIt<AudioDatabase>().init();
  await getIt<ReadingSessionDatabase>().init();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
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
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: appState.themeMode,
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
