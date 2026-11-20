import 'package:material_ui/material_ui.dart';

enum AppVisualTheme { liquidGlass, classic }

enum PlayerStyle { flagship, vinyl, edgeToEdge }

enum PlayerBackgroundStyle { ambientGlow, appleBlur, darkGradient, oledBlack }

enum SliderStyle { appleSlim, mochyWavy, liquidPill }

enum LyricsStyle { appleGlow, mochyMotion, karaokePill, minimal }

enum LyricsAlign { left, center, right }

enum AudioQualityTier { auto, high, medium, low }

enum GlassQuality { high, performance }

enum AccentPreset {
  rose(Color(0xFFFF375F), 'Hồng Rose'),
  indigo(Color(0xFF6E6BF5), 'Tím Indigo'),
  emerald(Color(0xFF2DD4BF), 'Ngọc Lục'),
  amber(Color(0xFFFF9F0A), 'Hổ Phách'),
  silver(Color(0xFFD8E0F0), 'Bạc Liquid');

  final Color color;
  final String label;
  const AccentPreset(this.color, this.label);
}

class AppSettings {
  static const List<String> defaultLyricsProviders = [
    'lrclib',
    'betterlyrics',
    'ytm',
    'lyricsovh',
  ];

  static const Map<String, String> providerDisplayNames = {
    'lrclib': 'LrcLib (Đồng bộ LRC)',
    'betterlyrics': 'BetterLyrics (Apple TTML)',
    'ytm': 'YouTube Music (Lời gốc)',
    'lyricsovh': 'Lyrics.ovh (Quốc tế)',
  };

  static const Map<String, List<double>> eqPresets = {
    'Flat': [0, 0, 0, 0, 0],
    'Bass Boost': [6, 4, 0, -1, 1],
    'Vocal': [-2, 1, 5, 4, 1],
    'Electronic': [5, 2, -1, 3, 5],
    'Acoustic': [2, 3, 2, 3, 2],
    'Late Night': [-3, 2, 3, 1, -2],
  };

  final AppVisualTheme visualTheme;
  final PlayerStyle playerStyle;
  final PlayerBackgroundStyle backgroundStyle;
  final SliderStyle sliderStyle;
  final LyricsStyle lyricsStyle;
  final LyricsAlign lyricsAlign;
  final double lyricsFontSize;
  final bool blurInactiveLyrics;
  final AudioQualityTier audioQuality;
  final AccentPreset accentPreset;
  final GlassQuality glassQuality;
  final List<String> lyricsProviderOrder;
  final List<String> enabledLyricsProviders;
  final double playbackSpeed;
  final double playbackPitch;
  final String eqPreset;
  final List<double> eqBands;

  const AppSettings({
    this.visualTheme = AppVisualTheme.liquidGlass,
    this.playerStyle = PlayerStyle.flagship,
    this.backgroundStyle = PlayerBackgroundStyle.ambientGlow,
    this.sliderStyle = SliderStyle.mochyWavy,
    this.lyricsStyle = LyricsStyle.appleGlow,
    this.lyricsAlign = LyricsAlign.left,
    this.lyricsFontSize = 21.0,
    this.blurInactiveLyrics = true,
    this.audioQuality = AudioQualityTier.high,
    this.accentPreset = AccentPreset.rose,
    this.glassQuality = GlassQuality.high,
    this.lyricsProviderOrder = defaultLyricsProviders,
    this.enabledLyricsProviders = defaultLyricsProviders,
    this.playbackSpeed = 1.0,
    this.playbackPitch = 1.0,
    this.eqPreset = 'Flat',
    this.eqBands = const [0, 0, 0, 0, 0],
  });

  Color get accentColor => accentPreset.color;
  bool get isClassic => visualTheme == AppVisualTheme.classic;
  bool get highGlass =>
      visualTheme == AppVisualTheme.liquidGlass &&
      glassQuality == GlassQuality.high;

  List<String> get activeLyricsProviders => lyricsProviderOrder
      .where((p) => enabledLyricsProviders.contains(p))
      .toList(growable: false);

  AppSettings copyWith({
    AppVisualTheme? visualTheme,
    PlayerStyle? playerStyle,
    PlayerBackgroundStyle? backgroundStyle,
    SliderStyle? sliderStyle,
    LyricsStyle? lyricsStyle,
    LyricsAlign? lyricsAlign,
    double? lyricsFontSize,
    bool? blurInactiveLyrics,
    AudioQualityTier? audioQuality,
    AccentPreset? accentPreset,
    GlassQuality? glassQuality,
    List<String>? lyricsProviderOrder,
    List<String>? enabledLyricsProviders,
    double? playbackSpeed,
    double? playbackPitch,
    String? eqPreset,
    List<double>? eqBands,
  }) {
    return AppSettings(
      visualTheme: visualTheme ?? this.visualTheme,
      playerStyle: playerStyle ?? this.playerStyle,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      sliderStyle: sliderStyle ?? this.sliderStyle,
      lyricsStyle: lyricsStyle ?? this.lyricsStyle,
      lyricsAlign: lyricsAlign ?? this.lyricsAlign,
      lyricsFontSize: lyricsFontSize ?? this.lyricsFontSize,
      blurInactiveLyrics: blurInactiveLyrics ?? this.blurInactiveLyrics,
      audioQuality: audioQuality ?? this.audioQuality,
      accentPreset: accentPreset ?? this.accentPreset,
      glassQuality: glassQuality ?? this.glassQuality,
      lyricsProviderOrder: lyricsProviderOrder ?? this.lyricsProviderOrder,
      enabledLyricsProviders:
          enabledLyricsProviders ?? this.enabledLyricsProviders,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      playbackPitch: playbackPitch ?? this.playbackPitch,
      eqPreset: eqPreset ?? this.eqPreset,
      eqBands: eqBands ?? this.eqBands,
    );
  }

  Map<String, dynamic> toJson() => {
        'visualTheme': visualTheme.name,
        'playerStyle': playerStyle.name,
        'backgroundStyle': backgroundStyle.name,
        'sliderStyle': sliderStyle.name,
        'lyricsStyle': lyricsStyle.name,
        'lyricsAlign': lyricsAlign.name,
        'lyricsFontSize': lyricsFontSize,
        'blurInactiveLyrics': blurInactiveLyrics,
        'audioQuality': audioQuality.name,
        'accentPreset': accentPreset.name,
        'glassQuality': glassQuality.name,
        'lyricsProviderOrder': lyricsProviderOrder,
        'enabledLyricsProviders': enabledLyricsProviders,
        'playbackSpeed': playbackSpeed,
        'playbackPitch': playbackPitch,
        'eqPreset': eqPreset,
        'eqBands': eqBands,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
      if (name == null) return fallback;
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    final rawOrder = (json['lyricsProviderOrder'] as List?)
            ?.whereType<String>()
            .where((p) => defaultLyricsProviders.contains(p))
            .toList() ??
        List<String>.from(defaultLyricsProviders);
    for (final p in defaultLyricsProviders) {
      if (!rawOrder.contains(p)) rawOrder.add(p);
    }

    final rawEnabled = (json['enabledLyricsProviders'] as List?)
            ?.whereType<String>()
            .where((p) => defaultLyricsProviders.contains(p))
            .toList() ??
        List<String>.from(defaultLyricsProviders);

    final rawBands = (json['eqBands'] as List?)
            ?.map((e) => (e as num).toDouble().clamp(-12.0, 12.0))
            .toList() ??
        const [0.0, 0.0, 0.0, 0.0, 0.0];

    return AppSettings(
      visualTheme: enumByName(
        AppVisualTheme.values,
        json['visualTheme'] as String?,
        AppVisualTheme.liquidGlass,
      ),
      playerStyle: enumByName(
        PlayerStyle.values,
        json['playerStyle'] as String?,
        PlayerStyle.flagship,
      ),
      backgroundStyle: enumByName(
        PlayerBackgroundStyle.values,
        json['backgroundStyle'] as String?,
        PlayerBackgroundStyle.ambientGlow,
      ),
      sliderStyle: enumByName(
        SliderStyle.values,
        json['sliderStyle'] as String?,
        SliderStyle.mochyWavy,
      ),
      lyricsStyle: enumByName(
        LyricsStyle.values,
        json['lyricsStyle'] as String?,
        LyricsStyle.appleGlow,
      ),
      lyricsAlign: enumByName(
        LyricsAlign.values,
        json['lyricsAlign'] as String?,
        LyricsAlign.left,
      ),
      lyricsFontSize:
          ((json['lyricsFontSize'] as num?)?.toDouble() ?? 21.0).clamp(16.0, 28.0),
      blurInactiveLyrics: json['blurInactiveLyrics'] as bool? ?? true,
      audioQuality: enumByName(
        AudioQualityTier.values,
        json['audioQuality'] as String?,
        AudioQualityTier.high,
      ),
      accentPreset: enumByName(
        AccentPreset.values,
        json['accentPreset'] as String?,
        AccentPreset.rose,
      ),
      glassQuality: enumByName(
        GlassQuality.values,
        json['glassQuality'] as String?,
        GlassQuality.high,
      ),
      lyricsProviderOrder: rawOrder,
      enabledLyricsProviders:
          rawEnabled.isEmpty ? List<String>.from(defaultLyricsProviders) : rawEnabled,
      playbackSpeed:
          ((json['playbackSpeed'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 2.0),
      playbackPitch:
          ((json['playbackPitch'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 2.0),
      eqPreset: json['eqPreset'] as String? ?? 'Flat',
      eqBands: rawBands.length == 5 ? rawBands : const [0, 0, 0, 0, 0],
    );
  }
}
