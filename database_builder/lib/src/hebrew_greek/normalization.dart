import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Normalizes a string for searching using a robust, two-step process.
/// 1. Decomposes characters into base letters and combining marks (e.g., "έ" -> "ε" + "́").
/// 2. Filters the result, keeping only whitelisted letters and converting to lowercase.
///
/// This correctly handles diacritics and punctuation for Hebrew and Greek.
///
/// Example: `normalizeForSearch("τὰ")`       -> `"τα"`
/// Example: `normalizeForSearch("ἀνέθη.")`    -> `"ανεθη"`
/// Example: `normalizeForSearch("ἀνδρός,")`    -> `"ανδρος"`
/// Example: `normalizeForSearch("שָׁלוֹם")`  -> `"שלום"`
String filterAllButHebrewGreekNoDiacritics(String text) {
  // Regex to match any character that is NOT a whitelisted letter.
  // This is applied *after* decomposition.
  final RegExp nonEssentialCharsRegex = RegExp(
    r'[^'
    // Hebrew alphabet (Alef to Tav) AND final forms.
    r'\u05D0-\u05EA\u05DA\u05DD\u05DF\u05E3\u05E5'
    // Greek alphabet (avoids Coptic and other symbols).
    r'\u0391-\u03C9'
    r']+',
    unicode: true,
  );

  // 1. Decompose the string into base characters and combining marks (NFD).
  String decomposed = unorm.nfd(text);

  // 2. Remove everything that is not a whitelisted base letter.
  String filtered = decomposed.replaceAll(nonEssentialCharsRegex, '');

  // 3. Convert to lowercase for case-insensitive matching.
  return filtered.toLowerCase();
}
