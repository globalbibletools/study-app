# Flutter

## Overview
macOS Flutter platform integration layer maintaining build configuration and generated native plugin registration bindings.

## Interface
- [GeneratedPluginRegistrant.swift:RegisterGeneratedPlugins(registry:)] - Registers all active macOS Flutter plugins with the provided `FlutterPluginRegistry`.

## Invariants
- Managed by Flutter build tooling to synchronize with dependencies declared in `pubspec.yaml`.

## Side Effects
- Registers native macOS plugin instances with the Flutter engine plugin registrar.

## Verification
- Run: `flutter test`
