# Runner

## Overview
macOS application runner target managing native NSApplication lifecycle, main window presentation, and Flutter view controller attachment.

## Interface
- [AppDelegate.swift:AppDelegate] - Native application delegate subclassing `FlutterAppDelegate` for macOS application lifecycle events.
- [AppDelegate.swift:AppDelegate.applicationShouldTerminateAfterLastWindowClosed(_:)] - Determines whether application terminates when its last window closes.
- [AppDelegate.swift:AppDelegate.applicationSupportsSecureRestorableState(_:)] - Enables secure restorable state handling.
- [MainFlutterWindow.swift:MainFlutterWindow] - Custom `NSWindow` hosting the desktop `FlutterViewController`.
- [MainFlutterWindow.swift:MainFlutterWindow.awakeFromNib()] - Instantiates the `FlutterViewController`, positions the window frame, and registers macOS plugins.

## Invariants
- Application terminates when the last window is closed.
- Generated plugins are registered during `MainFlutterWindow.awakeFromNib()`.

## Side Effects
- Allocates native macOS desktop window and initializes FlutterMacOS view controller.

## Verification
- Run: `flutter test`
