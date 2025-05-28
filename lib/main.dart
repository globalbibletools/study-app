import 'package:flutter/material.dart';
import 'package:studyapp/services/database.dart';
import 'package:studyapp/services/service_locator.dart';

import 'home/home.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  await getIt<HebrewGreekDatabase>().init();
  runApp(const GbtStudyApp());
}

class GbtStudyApp extends StatelessWidget {
  const GbtStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Bible Tools',
      theme: appTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
