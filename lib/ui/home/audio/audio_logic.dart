import 'package:studyapp/ui/home/audio/audio_manager.dart';

class AudioLogic {
  // Books 1-39 are OT. 40-66 are NT.
  static const int _firstNtBook = 40;

  // Specific OT books missing from the RDB collection
  static const Set<int> _missingRdbBooks = {
    13,
    14,
    16,
    24,
    26,
    28,
    29,
    30,
    33,
    39,
  };

  static bool isNewTestament(int bookId) {
    return bookId >= _firstNtBook;
  }

  static bool hasTimingData(int bookId) {
    // NT has no timing data.
    return !isNewTestament(bookId);
  }

  /// Determines the actual folder/recording ID to use based on book and preference.
  static String getRecordingId(int bookId, AudioSourceType userPreference) {
    // 1. New Testament Logic
    if (isNewTestament(bookId)) {
      // Assuming NT audio is stored in a specific folder, e.g., 'GNT' or 'GK'.
      // Update this string to match your backend/folder structure.
      return 'GNT';
    }

    // 2. Old Testament Logic
    // If the user wants RDB, but it's missing, force HEB.
    if (userPreference == AudioSourceType.rdb) {
      if (_missingRdbBooks.contains(bookId)) {
        return 'HEB';
      }
      return 'RDB';
    }

    // Default to HEB if preferred
    return 'HEB';
  }
}
