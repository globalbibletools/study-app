import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/design/severity_colors.dart';

void main() {
  group('SeverityColors', () {
    test('lerp returns self when other is null', () {
      expect(SeverityColors.dark.lerp(null, 0.5), same(SeverityColors.dark));
    });

    test('lerp interpolates each field', () {
      final result = SeverityColors.light.lerp(SeverityColors.dark, 0.5);
      expect(
        result.warningIcon,
        Color.lerp(const Color(0xFF92400E), const Color(0xFFFBBF24), 0.5),
      );
      expect(
        result.errorBackground,
        Color.lerp(const Color(0xFFFDE8E8), const Color(0xFF4A1210), 0.5),
      );
    });

    test('lerp at zero returns the original', () {
      final result = SeverityColors.dark.lerp(SeverityColors.light, 0.0);
      expect(result.infoBackground, SeverityColors.dark.infoBackground);
      expect(result.infoIcon, SeverityColors.dark.infoIcon);
    });

    test('copyWith changes only the given fields', () {
      final result = SeverityColors.dark.copyWith(
        errorIcon: const Color(0x00000001),
      );
      expect(result.errorIcon, const Color(0x00000001));
      expect(result.errorBackground, SeverityColors.dark.errorBackground);
      expect(result.infoIcon, SeverityColors.dark.infoIcon);
    });
  });
}
