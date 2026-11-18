import 'package:material_ui/material_ui.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/home.dart';

import 'app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  await getIt.allReady();
  info('App starting');
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  // Don't await this to not block launching the app.
  getIt<ResourceService>().refresh();
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
