import 'package:flutter/material.dart';

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF1A1617),
  primaryColor: const Color(0xFF00BFB2),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white, fontSize: 18),
    bodyMedium: TextStyle(color: Colors.white70),
    titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A1617),
    iconTheme: IconThemeData(color: Color(0xFF00BFB2)),
    titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
  ),
  iconTheme: const IconThemeData(color: Color(0xFF00BFB2)), // Added for general icons
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D2829), foregroundColor: Colors.white),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00BFB2),
    onPrimary: Colors.black,
    surface: Color(0xFF2D2829),
    onSurface: Colors.white,
  ),
);
