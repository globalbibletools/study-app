import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Normalizes a string for searching using a robust, multi-step process.
/// This handles diacritics, final-forms, and punctuation for Hebrew and Greek.
String normalizeHebrewGreek(String text) {
  // 1. Decompose the string into base characters and combining marks (NFD).
  String decomposed = unorm.nfd(text);

  // 2. Remove everything that is not a whitelisted base letter.
  final nonEssentialCharsRegex = RegExp(
    r'[^'
    // Hebrew alphabet (Alef to Tav) AND final forms.
    r'\u05D0-\u05EA\u05DA\u05DD\u05DF\u05E3\u05E5'
    // Greek alphabet (avoids Coptic and other symbols).
    r'\u0391-\u03C9'
    r']+',
    unicode: true,
  );
  String filtered = decomposed.replaceAll(nonEssentialCharsRegex, '');

  // 3. Convert any Hebrew final-form letters to their regular form.
  const Map<String, String> finalToRegularMap = {
    'ך': 'כ', // Final Kaf -> Kaf
    'ם': 'מ', // Final Mem -> Mem
    'ן': 'נ', // Final Nun -> Nun
    'ף': 'פ', // Final Pe -> Pe
    'ץ': 'צ', // Final Tsadi -> Tsadi
  };
  String normalizedHebrew = filtered.replaceAllMapped(RegExp('[ךםןףץ]'), (
    match,
  ) {
    return finalToRegularMap[match.group(0)!]!;
  });

  // 4. Convert to lowercase for case-insensitive matching (for Greek).
  return normalizedHebrew.toLowerCase();
}
