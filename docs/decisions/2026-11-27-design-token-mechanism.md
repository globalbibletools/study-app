# Design Token Mechanism

- Date: 2026-11-27
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

The design system plan calls for a token layer in `lib/design/`, and the
mechanism must be chosen before any token is written. Flutter offers several
channels for design values:

- `ThemeData`'s built-in slots: `ColorScheme`, `TextTheme`, component themes
  (`AppBarTheme`, button themes), and shape defaults.
- `ThemeExtension<T>`: arbitrary data registered per brightness, read
  through `Theme.of(context).extension<T>()`, with animated theme transitions
  if `lerp` is implemented.
- Plain constants: abstract final classes of `static const` values.

The wrong split scatters values across channels arbitrarily, and every
future author has to guess where a token lives. The inventory also found
three concrete token families to place: the severity palette
(brightness-dependent colors), spacing/radius/motion (brightness-independent
constants), and scripture typography sizes (user-adjustable, domain-coupled).

# Decisions

1. **Fill `ThemeData` before introducing extensions.** Anything the Material
   theme system can already express goes into its native slot: colors into
   `ColorScheme` roles, text styles into `TextTheme`, per-component styling
   into component themes. A `ThemeExtension` is created only for a value
   family that `ThemeData` has no slot for. Each extension should have a
   reason to exist that a reviewer can state in one sentence.

2. **Brightness-independent constants live in abstract final classes.**
   Spacing, radius, and motion tiers do not vary with theme, so they carry
   no extension, `copyWith`, or `lerp` boilerplate:

   ```dart
   abstract final class Spacing {
     static const double xs = 4;
     static const double sm = 8;
     static const double md = 16;
     static const double lg = 24;
     static const double xl = 32;
   }

   abstract final class RadiusScale {
     static const double sm = 8;
     static const double md = 12;
     static const double lg = 24;
     static const double pill = 999;
   }

   abstract final class Motion {
     static const Duration fast = Duration(milliseconds: 150);
     static const Duration normal = Duration(milliseconds: 250);
     static const Duration slow = Duration(milliseconds: 500);
   }
   ```

   `abstract final` makes the class a namespace: it cannot be instantiated
   or extended, so the constants are all there is. The accepted cost is two
   access channels — themed values via `Theme.of(context)`, constants via
   direct reference — traded for zero ceremony on the values that never
   vary.

3. **The severity palette is a `ThemeExtension`.** It is the first
   sanctioned extension: a multi-color family that must differ per
   brightness and that `ColorScheme` has no honest slot for. `ColorScheme`
   roles are predetermined Material 3 semantics — `secondaryContainer` is
   the muted brand container that `FilledButton.tonal`, `Badge`, and
   filter chips read automatically, not a free slot — so repurposing them
   for severity would silently restyle any future stock component that
   consumes them. The extension is registered in both themes in
   `lib/design/` and consumed via `context.severityColors`, a null-safe
   accessor that hides the raw `!`.

4. **Scripture typography is deferred.** The user-adjustable per-surface font
   scales (`baseFontSize` × `hebrewFontScale`/`greekFontScale`/…) are tied
   to `UserSettings` and the reading surfaces, so the tokenization of
   scripture text sizes is a domain-coupled decision, not a mechanism one.
   Until it is made, scripture components keep receiving font sizes as
   parameters. Plan item 0.3 tracks it.

# Implementation Notes

- The access channels are:
  1. `ColorScheme` / `TextTheme` — the default; always preferred.
  2. `Theme.of(context).extension<T>()!` — only for families with no slot.
     Each extension gets a null-safe accessor extension on `BuildContext`
     in `lib/design/` (e.g. `context.severityColors`) so call sites never
     write the raw `!`.
  3. Direct `Spacing`/`RadiusScale`/`Motion` references — constants, no
     context needed, usable in tests and const contexts.
- Widgets pumped in tests run under the app themes (`lightTheme`/
  `darkTheme`), the same discipline as seeding the locator: a hand-rolled
  `MaterialApp(theme: ThemeData())` has an empty extensions list, and
  `context.severityColors` would crash on it. A test needing a bespoke
  theme composes it from the app theme's extensions.
- The severity-to-field mapping (`MessageSeverity` → which severity color)
  lives with the consumer, in a severity switch, because `MessageSeverity`
  is owned by the messaging slice and the design foundation stays free of
  domain vocabulary. If severity becomes a cross-slice vocabulary, promote
  it to a generic enum in `lib/design/` and move the switch with it.
- `lib/theme.dart` moves into `lib/design/` and becomes the place where
  `ColorScheme`, `TextTheme`, component themes, and registered extensions
  are all constructed. Raw color/size literals outside `lib/design/` are
  the migration targets; the Phase 3 lint makes them fail CI once the
  migration of each slice is done.
- Adding a new value family first asks: which existing slot can hold it?
  Only after the answer is "none" may a constant class or extension be
  added, and the choice follows decisions 2 and 3.

# Alternatives

- **All values as `ThemeExtension`s, for one uniform access channel:**
  Discarded. Uniformity is attractive, but spacing and motion tiers pay
  `copyWith`/`lerp`/registration/lookup costs for values that never vary
  between themes; abstract final classes are simpler and usable in const
  expressions.
- **All values as plain constants:** Discarded for brightness-dependent
  families. A severity palette as constants needs parallel light/dark
  maps and manual brightness switching at every consumer, which is the
  pattern `messenger_host.dart` is being cleaned out of.
- **Severity colors in `ColorScheme` container roles:** Tried and
  rejected. The mapping fits numerically — four severities, four container
  pairs, `errorContainer` even matches semantically — but the roles are
  predetermined: M3's `FilledButton.tonal`, `Badge`, filter chips, and
  `InputDecorator` read them automatically, so a severity repurposing would
  silently restyle stock components and block normal container usage. The
  cost of the extension instead is boilerplate (`copyWith`/`lerp`) and the
  test requirement above.
- **Tokenizing scripture typography now:** Deferred as domain-coupled,
  not mechanism. It interacts with user settings persistence and the
  reading surfaces' scaling behavior and deserves its own decision.

# References

- [Shared Design Foundation](2026-11-27-shared-design-foundation.md)
- [Design system plan](../plans/design-system-plan.md) — this decision
  closes plan item 0.2; item 0.3 (typography) remains deferred
- `lib/ui/messaging/messenger_host.dart` — the severity palette's current
  home, and the first consumer of the new extension
