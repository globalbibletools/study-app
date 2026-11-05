# About

## Overview
Provides the application's About screen and localized Markdown viewing components, displaying app branding, version metadata, and legal/credit documentation.

## Interface
- `about.dart:AboutPage`: Stateful widget rendering app branding, package version, and embedded about markdown.
- `markdown_viewer.dart:LocalizedMarkdownViewer`: Stateless widget loading and displaying localized markdown assets with support for custom email copying and external link launching.

## Invariants
- None

## Side Effects
- Asynchronously queries platform package metadata (`PackageInfo.fromPlatform`).
- Reads asset bundle files from `assets/l10n/` with fallback to English.
- Copies email strings to system clipboard via `Clipboard.setData`.
- Dispatches external application intents via `url_launcher.launchUrl`.

## Verification
- Run: `flutter test`
