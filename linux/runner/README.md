# runner

## Overview
Linux application runner component providing the GTK entry point and hosting the Flutter Linux engine and view hierarchy.

## Interface
- [main.cc:main(int, char**)] - Executable entry point initializing and running `MyApplication`.
- [my_application.h:MyApplication] - GTK application structure extending `GtkApplication`.
- [my_application.h:my_application_new()] - Factory function creating the `MyApplication` instance with configured application ID.
- [my_application.cc:my_application_activate(GApplication*)] - Creates application window, attaches `FlView`, and registers plugins.
- [my_application.cc:my_application_local_command_line(GApplication*, gchar***, int*)] - Parses command-line arguments and passes them to Dart entry point.

## Invariants
- Uses GNOME header bar when running under GNOME Shell, falling back to standard window titlebar on other window managers.
- Registers plugins on the `FlPluginRegistry` associated with the active `FlView`.

## Side Effects
- Creates GTK window and allocates X11/Wayland rendering surfaces for the Flutter Linux engine.

## Verification
- Run: `flutter test`
