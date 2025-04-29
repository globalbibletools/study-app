import 'package:flutter/material.dart';

import 'home.dart';
import 'theme.dart';

void main() {
  runApp(BibleThemeApp());
}

class BibleThemeApp extends StatelessWidget {
  const BibleThemeApp({super.key});

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
