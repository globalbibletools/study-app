import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';

void main() {
  group('ResourceDownloadPromptDialog gloss decline tracking', () {
    var now = DateTime(2026, 11, 26, 12);

    setUp(() {
      now = DateTime(2026, 11, 26, 12);
      ResourceDownloadPromptDialog.clock = () => now;
      ResourceDownloadPromptDialog.resetDeclineTracking();
    });

    tearDown(() {
      ResourceDownloadPromptDialog.clock = DateTime.now;
      ResourceDownloadPromptDialog.resetDeclineTracking();
    });

    test('does not suppress before any decline', () {
      expect(ResourceDownloadPromptDialog.glossDeclinedRecently('es'), isFalse);
    });

    test('suppresses reprompt for one hour after a decline', () {
      ResourceDownloadPromptDialog.markGlossDeclined('es');

      now = now.add(const Duration(minutes: 59));
      expect(ResourceDownloadPromptDialog.glossDeclinedRecently('es'), isTrue);

      now = now.add(const Duration(minutes: 1));
      expect(ResourceDownloadPromptDialog.glossDeclinedRecently('es'), isFalse);
    });

    test('tracks each language separately', () {
      ResourceDownloadPromptDialog.markGlossDeclined('es');

      expect(ResourceDownloadPromptDialog.glossDeclinedRecently('fr'), isFalse);
      expect(ResourceDownloadPromptDialog.glossDeclinedRecently('es'), isTrue);
    });

    test('reset clears all decline state', () {
      ResourceDownloadPromptDialog.markGlossDeclined('es');

      ResourceDownloadPromptDialog.resetDeclineTracking();

      expect(ResourceDownloadPromptDialog.glossDeclinedRecently('es'), isFalse);
    });
  });
}
