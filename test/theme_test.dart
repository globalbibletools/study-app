import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/theme.dart';

void main() {
  group('darkTheme', () {
    test('is dark brightness', () {
      expect(darkTheme.brightness, Brightness.dark);
    });

    test('uses the teal primary color', () {
      expect(darkTheme.primaryColor, const Color(0xFF00BFB2));
    });

    test('has a black scaffold background', () {
      expect(darkTheme.scaffoldBackgroundColor, Colors.black);
    });
  });

  group('lightTheme', () {
    test('is light brightness', () {
      expect(lightTheme.brightness, Brightness.light);
    });

    test('uses the darker teal primary color', () {
      expect(lightTheme.primaryColor, const Color(0xFF007F76));
    });

    test('has a white scaffold background', () {
      expect(lightTheme.scaffoldBackgroundColor, Colors.white);
    });
  });

  test('themes have opposing brightness', () {
    expect(darkTheme.brightness, isNot(lightTheme.brightness));
  });
}
