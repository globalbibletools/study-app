import 'package:flutter/material.dart';

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  primaryColor: const Color(0xFF00BFB2),
  fontFamily: 'sbl',
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white, fontSize: 18),
    bodyMedium: TextStyle(color: Colors.white),
    titleLarge: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 22,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black,
    iconTheme: IconThemeData(color: Color(0xFF00BFB2)),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      fontFamily: 'sbl',
    ),
  ),
  iconTheme: const IconThemeData(
    color: Color(0xFF00BFB2),
  ), // Added for general icons
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontFamily: 'sbl'),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      textStyle: const TextStyle(fontFamily: 'sbl'),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: 'sbl')),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00BFB2),
    onPrimary: Colors.black,
    surface: Color.fromARGB(255, 30, 30, 30),
    onSurface: Colors.white,
  ),
);
