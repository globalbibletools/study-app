# Common

## Overview
Provides foundational Scripture domain models, coordinate types, canonical navigation rules, and collection definitions shared across the application. Encapsulates verse references, original language lexical word representations, chapter-level navigation state, book verse/chapter counts, liturgical and canonical book groupings, and localized book title lookups.

## Interface
- [word.dart:HebrewGreekWord]: Domain entity representing an original Hebrew or Greek lexical word token with reference coordinates and optional Strong's concordance code.
- [reference.dart:Reference]: Immutable value object representing a Scripture reference with canonical book ID, chapter, verse, and optional verse range `endVerse`.
- [bible_collection.dart:BibleCollection]: Model representing a biblical book grouping with numeric ID, English name, and member book IDs.
- [bible_collection.dart:BibleCollections]: Static registry of predefined Bible book collections (Whole Bible, Old Testament, New Testament, Torah, Prophets, Writings, Gospels, Pauline Epistles, Psalms), ID lookup, and localized name resolver.
- [bible_navigation.dart:ChapterIdentifier]: Immutable value type representing a specific book ID and chapter number pair.
- [bible_navigation.dart:BibleNavigation]: Static navigation engine providing bidirectional chapter traversal across the canon, reading plan chapter progression, canonical book ordering lists (`christianBooks`, `jewishBooks`, `easyToHard`), and chapter/verse count lookup tables.
- [book_name.dart:bookNameForId]: Resolves localized Scripture book names from `BuildContext` and canonical 1-based book ID (1..66).

## Invariants
- `Reference` constructor asserts `bookId >= 1 && bookId <= 66`, `chapter >= 1 && chapter <= 150`, and `endVerse == null || verse <= endVerse`.
- `BibleCollections.fromId(id)` expects 1-based indexing corresponding to `collections` elements 1 through 9.
- `bookNameForId(context, bookId)` throws `ArgumentError` if `bookId` is not within 1..66.
- `HebrewGreekWord.id` is an opaque packed string (`BBCCCVVVWW`) treated as an atomic token without client-side manual decoding.
- Canonical Bible limits are fixed: 66 total books, Old Testament books 1 through 39, and New Testament books 40 through 66.

## Side Effects
- None

## Verification
- Run: `flutter test`
