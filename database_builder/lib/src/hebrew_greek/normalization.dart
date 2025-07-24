import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Normalizes a search phrase for Hebrew and Greek.
///
/// This function performs several steps:
/// 1. Decomposes characters into base forms + combining marks (e.g., "έ" -> "ε" + "´").
/// 2. Removes any character that is not a Hebrew letter, Greek letter, or whitespace.
/// 3. Collapses any sequence of multiple whitespace characters into a single space
///    and trims leading/trailing whitespace.
/// 4. Converts Hebrew and Greek final-form letters to their standard forms.
///    (e.g., ך -> כ, ם -> מ, ..., and ς -> σ).
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
    // Hebrew alphabet (Alef to Tav)
    r'\u05D0-\u05EA'
    // Greek alphabet (avoids Coptic and other symbols)
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

  // 4. Convert to lowercase for case-insensitive matching (for Greek).
  final lowercase = cleanedWhitespace.toLowerCase();

  // 5. Convert Hebrew and Greek final-form letters to their regular form.
  const finalToRegularMap = {
    // Hebrew
    'ך': 'כ', // Final Kaf -> Kaf
    'ם': 'מ', // Final Mem -> Mem
    'ן': 'נ', // Final Nun -> Nun
    'ף': 'פ', // Final Pe -> Pe
    'ץ': 'צ', // Final Tsadi -> Tsadi
    // Greek
    'ς': 'σ', // Final Sigma -> Sigma
  };
  final normalizedFinalForms = lowercase.replaceAllMapped(RegExp('[ךםןףץς]'), (
    match,
  ) {
    return finalToRegularMap[match.group(0)!]!;
  });

  return normalizedFinalForms;
}

/// Automatically corrects the use of final-form letters for both Hebrew and
/// Greek within a string.
///
/// This function implements two main rules:
/// 1. A final-form letter (e.g., 'ך', 'ם', 'ς') found in the middle of a word
///    is converted back to its regular form.
/// 2. A regular-form letter that has a final version (e.g., 'כ', 'מ', 'σ')
///    found at the very end of a multi-letter word is converted to its final form.
///
/// It correctly handles punctuation, numbers, and mixed-language
/// text without breaking. Single-letter words are correctly kept in their
/// regular form.
String fixFinalForms(String text) {
  const Map<String, String> regularToFinal = {
    // Hebrew
    'כ': 'ך', 'מ': 'ם', 'נ': 'ן', 'פ': 'ף', 'צ': 'ץ',
    // Greek
    'σ': 'ς',
  };

  const finalToRegular = {
    // Hebrew
    'ך': 'כ', // Final Kaf -> Kaf
    'ם': 'מ', // Final Mem -> Mem
    'ן': 'נ', // Final Nun -> Nun
    'ף': 'פ', // Final Pe -> Pe
    'ץ': 'צ', // Final Tsadi -> Tsadi
    // Greek
    'ς': 'σ',
  };

  // Regex for letters that have a final form.
  const hebrewFinalCapable = '[כמנפצ]';
  const hebrewFinal = '[ךםןףץ]';
  const greekFinalCapable = '[σΣ]';
  const greekFinal = 'ς';

  // Regex for any letter of the given script.
  const hebrewLetter = '[\u05D0-\u05EA]';
  const greekLetter = '[\u0391-\u03C9]';

  // --- Step 1: Correct final letters that are in the middle of a word. ---
  // A final letter is incorrect if it is followed by another letter from the
  // same script. We use a positive lookahead `(?=...)` to check this.
  final fixIncorrectFinalsRegex = RegExp(
    '($hebrewFinal)(?=$hebrewLetter)|($greekFinal)(?=$greekLetter)',
    unicode: true,
  );
  String correctedText = text.replaceAllMapped(fixIncorrectFinalsRegex, (
    match,
  ) {
    // If group 1 (Hebrew) matched, or group 2 (Greek) matched.
    final char = match.group(1) ?? match.group(2)!;
    return finalToRegular[char]!;
  });

  // --- Step 2: Create final letters at the end of multi-letter words. ---
  // A regular letter should be final if it's preceded by a letter of the same
  // script (making it a multi-letter word) AND not followed by a letter of
  // the same script (making it the end of the word).
  final createCorrectFinalsRegex = RegExp(
    '(?<=$hebrewLetter)($hebrewFinalCapable)(?!$hebrewLetter)|'
    '(?<=$greekLetter)($greekFinalCapable)(?!$greekLetter)',
    unicode: true,
  );
  correctedText = correctedText.replaceAllMapped(createCorrectFinalsRegex, (
    match,
  ) {
    final char = match.group(1) ?? match.group(2)!;
    return regularToFinal[char]!;
  });

  return correctedText;
}
