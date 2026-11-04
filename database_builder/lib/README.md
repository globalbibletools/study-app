# Database Builder Library

## Overview
Serves as the root library and CLI entrypoint for the `database_builder` package, exposing database schemas and text normalization helpers to consuming packages, and providing executable routines to build all study SQLite databases.

## Interface
- `[database_builder.dart]`: Library root exporting public database schema contracts (`HebrewGreekSchema`, `GlossSchema`, `LexiconSchema`, `BibleSchema`) and normalization functions (`normalizeHebrewGreek`, `removePunctuation`, `fixFinalForms`).
- `[main.dart:main]`: Command-line execution entrypoint orchestrating database generation routines for original languages, lexicons, translations, glosses, and audio timings.
- [src](./src/README.md): Subsystems containing domain-specific database builders, schema models, and canonical scripture metadata.

## Invariants
- `database_builder.dart` only re-exports schema definitions and normalization utilities, isolating pipeline build dependencies from runtime consumers.
- Builder functions invoked by `main` delete pre-existing database files before rebuilding to ensure fresh state.

## Side Effects
- Executing `main` reads datasets from disk, creates or overwrites SQLite database files (`hebrew_greek.db`, `audio_timings.db`, `sdbh.db`, `sdbg.db`, and translation databases), and prints progress logs to standard output.

## Verification
- Run: `dart test`
