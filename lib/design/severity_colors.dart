import 'package:material_ui/material_ui.dart';

@immutable
class SeverityColors extends ThemeExtension<SeverityColors> {
  const SeverityColors({
    required this.infoBackground,
    required this.infoIcon,
    required this.successBackground,
    required this.successIcon,
    required this.warningBackground,
    required this.warningIcon,
    required this.errorBackground,
    required this.errorIcon,
  });

  static const dark = SeverityColors(
    infoBackground: Color(0xFF123B3A),
    infoIcon: Color(0xFF7FF0E6),
    successBackground: Color(0xFF123B3A),
    successIcon: Color(0xFF7FF0E6),
    warningBackground: Color(0xFF4A3800),
    warningIcon: Color(0xFFFBBF24),
    errorBackground: Color(0xFF4A1210),
    errorIcon: Color(0xFFF87171),
  );

  static const light = SeverityColors(
    infoBackground: Color(0xFFE0F2F1),
    infoIcon: Color(0xFF00796B),
    successBackground: Color(0xFFE0F2F1),
    successIcon: Color(0xFF00796B),
    warningBackground: Color(0xFFFFF1CC),
    warningIcon: Color(0xFF92400E),
    errorBackground: Color(0xFFFDE8E8),
    errorIcon: Color(0xFFB3261E),
  );

  final Color infoBackground;
  final Color infoIcon;
  final Color successBackground;
  final Color successIcon;
  final Color warningBackground;
  final Color warningIcon;
  final Color errorBackground;
  final Color errorIcon;

  @override
  SeverityColors copyWith({
    Color? infoBackground,
    Color? infoIcon,
    Color? successBackground,
    Color? successIcon,
    Color? warningBackground,
    Color? warningIcon,
    Color? errorBackground,
    Color? errorIcon,
  }) {
    return SeverityColors(
      infoBackground: infoBackground ?? this.infoBackground,
      infoIcon: infoIcon ?? this.infoIcon,
      successBackground: successBackground ?? this.successBackground,
      successIcon: successIcon ?? this.successIcon,
      warningBackground: warningBackground ?? this.warningBackground,
      warningIcon: warningIcon ?? this.warningIcon,
      errorBackground: errorBackground ?? this.errorBackground,
      errorIcon: errorIcon ?? this.errorIcon,
    );
  }

  @override
  SeverityColors lerp(SeverityColors? other, double t) {
    if (other == null) return this;
    return SeverityColors(
      infoBackground: Color.lerp(infoBackground, other.infoBackground, t)!,
      infoIcon: Color.lerp(infoIcon, other.infoIcon, t)!,
      successBackground: Color.lerp(
        successBackground,
        other.successBackground,
        t,
      )!,
      successIcon: Color.lerp(successIcon, other.successIcon, t)!,
      warningBackground: Color.lerp(
        warningBackground,
        other.warningBackground,
        t,
      )!,
      warningIcon: Color.lerp(warningIcon, other.warningIcon, t)!,
      errorBackground: Color.lerp(errorBackground, other.errorBackground, t)!,
      errorIcon: Color.lerp(errorIcon, other.errorIcon, t)!,
    );
  }
}

extension SeverityColorsAccess on BuildContext {
  SeverityColors get severityColors =>
      Theme.of(this).extension<SeverityColors>()!;
}
