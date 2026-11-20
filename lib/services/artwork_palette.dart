import 'dart:async';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

class ArtworkPalette {
  final Color darkSurface;
  final Color deepBackground;
  final Color vibrantAccent;

  const ArtworkPalette({
    required this.darkSurface,
    required this.deepBackground,
    required this.vibrantAccent,
  });

  static const fallback = ArtworkPalette(
    darkSurface: Color(0xFF16161B),
    deepBackground: Color(0xFF0A0A0D),
    vibrantAccent: Color(0xFFFFFFFF),
  );
}

/// Fast pure-Dart dominant color extractor for album covers (no extra plugin).
/// Decodes a tiny 24x24 sample via Flutter's native codec and computes a clean
/// dark backdrop color + vibrant highlight matching each song's cover art.
class ArtworkPaletteService {
  static final Map<String, ArtworkPalette> _cache = {};
  static final Map<String, Future<ArtworkPalette>> _inFlight = {};

  static ArtworkPalette? peek(String? url) =>
      url == null ? null : _cache[url];

  static Future<ArtworkPalette> extract(String? url) async {
    if (url == null || url.isEmpty) return ArtworkPalette.fallback;
    final cached = _cache[url];
    if (cached != null) return cached;
    final pending = _inFlight[url];
    if (pending != null) return pending;

    final task = _compute(url);
    _inFlight[url] = task;
    try {
      final result = await task;
      _cache[url] = result;
      if (_cache.length > 60) {
        _cache.remove(_cache.keys.first);
      }
      return result;
    } finally {
      _inFlight.remove(url);
    }
  }

  static Future<ArtworkPalette> _compute(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        return ArtworkPalette.fallback;
      }
      final codec = await ui.instantiateImageCodec(
        res.bodyBytes,
        targetWidth: 24,
        targetHeight: 24,
      );
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      codec.dispose();
      if (byteData == null) return ArtworkPalette.fallback;

      final bytes = byteData.buffer.asUint8List();
      double sumR = 0, sumG = 0, sumB = 0, totalWeight = 0;
      Color bestVibrant = const Color(0xFFFFFFFF);
      double bestScore = -1;

      for (int i = 0; i + 3 < bytes.length; i += 4) {
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];
        final a = bytes[i + 3];
        if (a < 180) continue;

        final c = Color.fromARGB(255, r, g, b);
        final hsl = HSLColor.fromColor(c);
        final weight = 0.25 + hsl.saturation * 1.4;
        sumR += r * weight;
        sumG += g * weight;
        sumB += b * weight;
        totalWeight += weight;

        // Score vibrant mid-tone pixels for subtle highlight accents
        if (hsl.saturation > 0.28 &&
            hsl.lightness > 0.25 &&
            hsl.lightness < 0.78) {
          final score =
              hsl.saturation * (1.0 - (hsl.lightness - 0.52).abs());
          if (score > bestScore) {
            bestScore = score;
            bestVibrant = hsl
                .withLightness(hsl.lightness.clamp(0.55, 0.72))
                .withSaturation(hsl.saturation.clamp(0.35, 0.78))
                .toColor();
          }
        }
      }

      if (totalWeight <= 0) return ArtworkPalette.fallback;

      final avg = Color.fromARGB(
        255,
        (sumR / totalWeight).round().clamp(0, 255),
        (sumG / totalWeight).round().clamp(0, 255),
        (sumB / totalWeight).round().clamp(0, 255),
      );
      final avgHsl = HSLColor.fromColor(avg);

      // Rich Mochy/Apple dark tinted canvas derived from the album cover hue
      final darkSurface = avgHsl
          .withSaturation((avgHsl.saturation * 0.65).clamp(0.06, 0.42))
          .withLightness(0.11)
          .toColor();
      final deepBg = avgHsl
          .withSaturation((avgHsl.saturation * 0.55).clamp(0.04, 0.34))
          .withLightness(0.055)
          .toColor();

      return ArtworkPalette(
        darkSurface: darkSurface,
        deepBackground: deepBg,
        vibrantAccent: bestScore > 0 ? bestVibrant : const Color(0xFFFFFFFF),
      );
    } catch (_) {
      return ArtworkPalette.fallback;
    }
  }
}
