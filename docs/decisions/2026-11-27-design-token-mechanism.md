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

3. **The severity palette becomes a `ThemeExtension`.** It is the first
   sanctioned extension: a multi-color family that must differ per
   brightness, with no `ColorScheme` slots for success/warning/info
   backgrounds and icons. It is registered in both themes in
   `lib/design/` and consumed via
   `Theme.of(context).extension<SeverityColors>()!`.

4. **Scripture typography is deferred.** The user-adjustable per-surface font
   scales (`baseFontSize` × `hebrewFontScale`/`greekFontScale`/…) are tied
   to `UserSettings` and the reading surfaces, so the tokenization of
   scripture text sizes is a domain-coupled decision, not a mechanism one.
   Until it is made, scripture components keep receiving font sizes as
   parameters. Plan item 0.3 tracks it.

# Implementation Notes

- The access channels are:
  1. `ColorScheme` / `TextTheme` — the default; always preferred.
  2. `Theme.of(context).extension<T>()!` — only for families like severity.
     Each extension gets a null-safe accessor extension on `BuildContext`
     in `lib/design/` (e.g. `context.severityColors`) so call sites never
     write the raw `!`.
  3. Direct `Spacing`/`RadiusScale`/`Motion` references — constants, no
     context needed, usable in tests and const contexts.
- Extensions must implement `lerp` for correct animated theme
  transitions; constant-style extensions may `lerp` by returning
  themselves, but per the decisions above such values are constants, not
  extensions, so this should be rare.
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
- **Semantic roles only in `ColorScheme` (no severity extension), mapping
  info/success/warning onto existing roles:** Discarded. `ColorScheme` has
  `error` but no success/warning/info trio with per-severity backgrounds;
  overloading `tertiary`/`secondary` would make the theme data lie about
  what the colors mean.
- **Tokenizing scripture typography now:** Deferred as domain-coupled,
  not mechanism. It interacts with user settings persistence and the
  reading surfaces' scaling behavior and deserves its own decision.

# References

- [Shared Design Foundation](2026-11-27-shared-design-foundation.md)
- [Design system plan](../plans/design-system-plan.md) — this decision
  closes plan item 0.2; item 0.3 (typography) remains deferred
- `lib/ui/messaging/messenger_host.dart` — the severity palette's current
  home, and the first consumer of the new extension
