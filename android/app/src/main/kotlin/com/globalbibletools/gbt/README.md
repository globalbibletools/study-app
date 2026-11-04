# gbt

## Overview
Android platform package providing the primary activity entry point for running the Flutter application within the Android runtime environment.

## Interface
- [MainActivity.kt:MainActivity] - Extends `FlutterActivity` to host the Flutter engine and application window lifecycle.

## Invariants
- Extends `FlutterActivity` without overriding default behavior unless custom platform channels or lifecycle hooks are needed.

## Side Effects
- Initializes the Flutter Android engine and attaches to the Android window manager.

## Verification
- Run: `flutter test`
