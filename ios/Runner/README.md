# Runner

## Overview
iOS application runner target providing the native CocoaTouch application delegate, window hosting, and Flutter engine and plugin initialization.

## Interface
- [AppDelegate.swift:AppDelegate] - Application delegate subclassing `FlutterAppDelegate` and `FlutterImplicitEngineDelegate` to manage iOS application lifecycle.
- [AppDelegate.swift:AppDelegate.application(_:didFinishLaunchingWithOptions:)] - Native launch entry point initializing Flutter application delegate.
- [AppDelegate.swift:AppDelegate.didInitializeImplicitFlutterEngine(_:)] - Lifecycle callback invoked when the implicit Flutter engine initializes, registering plugins.
- [GeneratedPluginRegistrant.h:GeneratedPluginRegistrant] - Generated plugin registrant class coordinating plugin registration.
- [GeneratedPluginRegistrant.h:GeneratedPluginRegistrant.registerWithRegistry:] - Method to register installed Flutter plugins with the provided `FlutterPluginRegistry`.

## Invariants
- Must register plugins with the implicit Flutter engine bridge upon initialization.
- Extends `FlutterAppDelegate` to maintain standard Flutter iOS application lifecycle.

## Side Effects
- Initializes the Flutter iOS engine, displays the primary UIWindow, and registers native iOS plugins.

## Verification
- Run: `flutter test`
