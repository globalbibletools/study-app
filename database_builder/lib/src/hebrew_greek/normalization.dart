import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Normalizes a search phrase for Hebrew and Greek.
///
/// This function performs several steps:
/// 1. Decomposes characters into base forms + combining marks (e.g., "έ" -> "ε" + "´").
/// 2. Removes any character that is not a Hebrew letter, Greek letter, or whitespace.
/// 3. Collapses any sequence of multiple whitespace characters into a single space
///    and trims leading/trailing whitespace.
/// 4. Converts Hebrew final-form letters (ך, ם, ן, ף, ץ) to their standard forms.
/// 5. Converts the entire string to lowercase for case-insensitive Greek matching.
///
/// Example:
/// Input:  "  Λόγος   καὶ   אֱלֹהִים׃  "
/// Output: "λογος και אלהים"
///
/// The output is ready to be split into a list of words: `output.split(' ')`
String normalizeHebrewGreek(String text) {
  // 1. Decompose the string into base characters and combining marks (NFD).
  final String decomposed = unorm.nfd(text);

  // 2. Remove everything that is not a whitelisted base letter or a space.
  final nonEssentialCharsRegex = RegExp(
    r'[^'
    r' ' // Keep spaces
    // Hebrew alphabet (Alef to Tav) AND final forms.
    r'\u05D0-\u05EA\u05DA\u05DD\u05DF\u05E3\u05E5'
    // Greek alphabet (avoids Coptic and other symbols).
    r'\u0391-\u03C9'
    r']+',
    unicode: true,
  );
  final String filtered = decomposed.replaceAll(nonEssentialCharsRegex, '');

  // 3. Clean up whitespace: collapse multiple spaces/newlines into a single
  //    space and trim the result. This handles messy user input gracefully.
  final multipleWhitespaceRegex = RegExp(r'\s+');
  final String cleanedWhitespace = filtered
      .replaceAll(multipleWhitespaceRegex, ' ')
      .trim();

  // 4. Convert any Hebrew final-form letters to their regular form.
  const Map<String, String> finalToRegularMap = {
    'ך': 'כ', // Final Kaf -> Kaf
    'ם': 'מ', // Final Mem -> Mem
    'ן': 'נ', // Final Nun -> Nun
    'ף': 'פ', // Final Pe -> Pe
    'ץ': 'צ', // Final Tsadi -> Tsadi
  };
  final String normalizedHebrew = cleanedWhitespace.replaceAllMapped(
    RegExp('[ךםןףץ]'),
    (match) {
      return finalToRegularMap[match.group(0)!]!;
    },
  );

  // 5. Convert to lowercase for case-insensitive matching (for Greek).
  return normalizedHebrew.toLowerCase();
}
