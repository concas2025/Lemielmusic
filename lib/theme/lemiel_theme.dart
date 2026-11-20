import 'package:material_ui/material_ui.dart';
import '../models/app_settings.dart';

/// BitChord + Mochy Music inspired pure monochrome obsidian design tokens.
/// Default accent is pure White (#FFFFFF) on pitch Black (#000000) — color
/// comes from actual album artwork rather than garish red UI chrome.
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
  Color get onAccent =>
      accent.computeLuminance() > 0.55 ? Colors.black : Colors.white;

  // BitChord & Mochy exact neutral OLED hierarchy
  Color get canvas => const Color(0xFF000000);
  Color get surface =>
      isClassic ? const Color(0xFF141417) : const Color(0xFF121215);
  Color get surfaceVariant =>
      isClassic ? const Color(0xFF1C1C20) : const Color(0xFF1B1B1F);
  Color get surfaceElevated =>
      isClassic ? const Color(0xFF222227) : const Color(0xFF1C1C20);
  Color get textSecondary => const Color(0xFF8E8E93);
  Color get textMuted => const Color(0xFF636366);
  Color get divider => const Color(0xFF222226);

  static LemielTheme fromSettings(AppSettings s) => LemielTheme(
        visualTheme: s.visualTheme,
        accent: s.accentColor,
        highGlass: s.highGlass,
      );

  static LemielTheme of(BuildContext context) {
    return Theme.of(context).extension<LemielTheme>() ??
        const LemielTheme(
          visualTheme: AppVisualTheme.liquidGlass,
          accent: Color(0xFFFFFFFF),
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
