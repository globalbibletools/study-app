# Domain Guide

Terminology and the problems this app is solving. Read this before working
anywhere domain terms appear, so that code names, UI copy, and conversations
are interpreted correctly.

## The problem we are solving

Bible students studying the original languages need to read Hebrew and Greek
text with immediate lexical help. Existing tools are desktop-bound, online
only, or too heavyweight. This app is an **offline-first, cross-platform
reader** where users:

1. Read the Hebrew Old Testament and Greek New Testament directly.
2. Tap any word to get a quick translation, grammatical analysis, and
   dictionary entry.
3. Study how a word is used across the whole biblical corpus.
4. Follow reading plans that track verse-by-verse progress in the original
   languages.

Everything must work offline after the needed resources are downloaded.

## Core domain concepts

### The text

**Hebrew/Greek text (original language text)** — the base text users read:
the Hebrew Old Testament and the Greek New Testament. All reading, plans, and
study happen in these texts; translations are an optional aid.

**Reference** — a pointer to a passage: book, chapter, verse, and optionally
a verse range. Books are identified by number 1–66 in canonical Protestant
order (Old Testament 1–39, New Testament 40–66).

**Word occurrence** — one specific word at one specific place in the text.
Each occurrence has its own identity, distinct from the lemma it belongs to.

**Lemma / root** — the dictionary form of a word. Many surface forms across
the corpus share one lemma.

**Strong's code** — the standard lexical identifier for a Hebrew or Greek
word (e.g. `H1732` for David, `G26` for love). Used to look up lexicon
entries and to group occurrences of the same lemma.

**Grammar / morphology** — the grammatical features of a word form: stem,
conjugation, person, gender, number, state (e.g. `3ms` = "3rd person
masculine singular"). The app translates these codes into readable
descriptions.

**Versification** — the mapping of text into chapter and verse numbers.
Verse numbers do **not** always agree between the Hebrew text and ancient or
modern translations (e.g. the Septuagint or Vulgate vs. the Masoretic Text).
Do not assume two resources agree on the numbering of a passage; aligning
divergent versification is a known future milestone, not solved today.

### Lexical study

**Gloss** — a short translation of a *specific word occurrence*, in the
user's chosen gloss language. Glosses may be AI-generated. Contrast with a
lexicon entry.

**Lexicon** — a full dictionary *article* for a word or lemma: definitions
and usage discussion, as opposed to the gloss's quick one-line translation.

**Word study** — the flow of inspecting a tapped word. This involves the
lemma and grammar information, as well as reviewing occurrences of the word
in the text.

**Occurrence search** — a concordance-style search for every verse containing
a word. Two modes: search this exact surface form, or search all forms of the
lemma (root). The results page is historically called "similar verses";
"occurrences" is the preferred term.

**Parallel translations** — showing one or more downloaded Bible translations
beneath an original-language verse (or occurrence result) for comparison.
There is deliberately no word-level alignment between the original text and
the translation.

### Resources

**Resource** — a unit of downloadable content, of one of three kinds:
glosses, a Bible translation, or audio narration. A resource is identified by
an id that is meaningful within its kind (a language code for glosses, a
translation id for bibles).

**Catalog** — the set of resources available from the server, including ones
not yet installed; users can download catalog items from within the app.

**Manifest** — the server's inventory of resources, including when each was
last updated and a checksum. Installed resources are compared against it to
detect outdated or removed items.

### Reading plans

**Reading plan** — a named plan over a **Bible collection** with a **daily
goal**, plus an optional custom book order and bookmark flag. Plans track
verse-by-verse progress in the original-language text.

**Bible collection** — a preset set of books: Whole Bible, Old Testament,
New Testament, Torah, Prophets, Writings, Gospels, Pauline Epistles, Psalms.
A plan whose ordered book list does not match a preset is shown as **Custom**;
the book list, not the stored collection id, is the source of truth.

**Daily goal** — either a number of verses or a number of minutes per day.
Days are marked when the goal was met.

**Reading session** — one sitting of reading on a given date: seconds read
and verses read. A session is either timed (recorded while the user reads)
or **manual** (totals entered by the user after the fact). Manual sessions
count toward the day's activity totals and goal, but they do not mark
individual verses read.

**Read log** — one record per verse-read event, tied to both a session and a
plan. Reading sessions account for time and verse totals, while the read log
accounts for which verses were read.

**Book completion** — a book is complete when every verse in it has been read
at least once, regardless of the order chapters and verses were read in.

