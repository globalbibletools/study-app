import 'package:flutter/material.dart';

// The original bright teal (Best for Dark backgrounds)
const _primaryColorDark = Color(0xFF00BFB2);

// A darker, richer teal (Best for Light backgrounds)
// This is a darker shade of the original hue to ensure readability on white.
const _primaryColorLight = Color(0xFF007F76);

const _fontFamily = 'sbl';

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  primaryColor: _primaryColorDark,
  fontFamily: _fontFamily,
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
    iconTheme: IconThemeData(color: _primaryColorDark),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      fontFamily: _fontFamily,
    ),
  ),
  iconTheme: const IconThemeData(color: _primaryColorDark),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontFamily: _fontFamily),
      side: const BorderSide(
        color: _primaryColorDark,
      ), // Added border for visibility
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _primaryColorDark,
      side: const BorderSide(color: _primaryColorDark),
      textStyle: const TextStyle(fontFamily: _fontFamily),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _primaryColorDark,
      textStyle: const TextStyle(fontFamily: _fontFamily),
    ),
  ),
  colorScheme: const ColorScheme.dark(
    primary: _primaryColorDark,
    onPrimary: Colors.black,
    surface: Color.fromARGB(255, 30, 30, 30),
    onSurface: Colors.white,
  ),
);

final lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  primaryColor: _primaryColorLight, // Using the new darker teal
  fontFamily: _fontFamily,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black, fontSize: 18),
    bodyMedium: TextStyle(color: Colors.black),
    titleLarge: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 22,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0, // Flat look usually looks cleaner in light mode
    scrolledUnderElevation: 2, // Slight shadow when scrolling
    iconTheme: IconThemeData(color: _primaryColorLight),
    titleTextStyle: TextStyle(
      color: Colors.black,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      fontFamily: _fontFamily,
    ),
  ),
  iconTheme: const IconThemeData(color: _primaryColorLight),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _primaryColorLight,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontFamily: _fontFamily),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _primaryColorLight,
      side: const BorderSide(color: _primaryColorLight),
      textStyle: const TextStyle(fontFamily: _fontFamily),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _primaryColorLight,
      textStyle: const TextStyle(fontFamily: _fontFamily),
    ),
  ),
  colorScheme: const ColorScheme.light(
    primary: _primaryColorLight,
    onPrimary: Colors.white,
    surface: Color(0xFFF5F5F5),
    onSurface: Colors.black,
    // Secondary can be used for accents
    secondary: _primaryColorLight,
  ),
);
