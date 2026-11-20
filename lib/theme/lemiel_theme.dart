import 'package:material_ui/material_ui.dart';
import '../models/app_settings.dart';

/// Unified visual design tokens powering both Liquid Glass and Classic themes.
/// Both modes share identical layout, spacing, typography, and controls — only
/// surfaces, background depth, and glass intensity adapt cleanly.
@immutable
class LemielTheme extends ThemeExtension<LemielTheme> {
  final AppVisualTheme visualTheme;
  final Color accent;
  final bool highGlass;

  const LemielTheme({
    required this.visualTheme,
    required this.accent,
    required this.highGlass,
  });

  bool get isClassic => visualTheme == AppVisualTheme.classic;
  bool get isLiquidGlass => visualTheme == AppVisualTheme.liquidGlass;

  Color get canvas => isClassic ? const Color(0xFF0E1016) : const Color(0xFF06060A);
  Color get surface => isClassic ? const Color(0xFF171A23) : const Color(0xFF161622);
  Color get surfaceElevated =>
      isClassic ? const Color(0xFF1F2330) : const Color(0xFF1A1A26);
  Color get border => isClassic
      ? Colors.white.withValues(alpha: 0.09)
      : Colors.white.withValues(alpha: 0.22);

  static LemielTheme fromSettings(AppSettings s) => LemielTheme(
        visualTheme: s.visualTheme,
        accent: s.accentColor,
        highGlass: s.highGlass,
      );

  static LemielTheme of(BuildContext context) {
    return Theme.of(context).extension<LemielTheme>() ??
        const LemielTheme(
          visualTheme: AppVisualTheme.liquidGlass,
          accent: Color(0xFFFF375F),
          highGlass: true,
        );
  }

  @override
  LemielTheme copyWith({
    AppVisualTheme? visualTheme,
    Color? accent,
    bool? highGlass,
  }) {
    return LemielTheme(
      visualTheme: visualTheme ?? this.visualTheme,
      accent: accent ?? this.accent,
      highGlass: highGlass ?? this.highGlass,
    );
  }

  @override
  LemielTheme lerp(ThemeExtension<LemielTheme>? other, double t) {
    if (other is! LemielTheme) return this;
    return LemielTheme(
      visualTheme: t < 0.5 ? visualTheme : other.visualTheme,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      highGlass: t < 0.5 ? highGlass : other.highGlass,
    );
  }
}
