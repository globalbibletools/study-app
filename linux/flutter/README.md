# flutter

## Overview
Linux platform support directory managing CMake configuration and generated native plugin registration routines.

## Interface
- [generated_plugin_registrant.h:fl_register_plugins(FlPluginRegistry*)] - Function registering all active Linux Flutter plugins with the plugin registry.

## Invariants
- Maintained by Flutter tooling to match plugins configured in `pubspec.yaml`.

## Side Effects
- Registers native Linux plugin handlers with the Flutter engine registrar.

## Verification
- Run: `flutter test`
