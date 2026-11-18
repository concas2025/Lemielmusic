import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

class LyricsService {
  final Map<String, List<LyricLine>> _cache = {};

  Future<List<LyricLine>> fetchLyrics(Track track) async {
    if (_cache.containsKey(track.id)) return _cache[track.id]!;

    final cleanTitle = track.title
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
        .trim();
    final cleanArtist = track.artist.split(RegExp(r'[,&•]')).first.trim();

    Map<String, dynamic>? best;

    // 1. Exact lookup when duration is known.
    if (track.durationSeconds > 0 && cleanTitle.isNotEmpty) {
      try {
        final uri = Uri.https('lrclib.net', '/api/get', {
          'track_name': cleanTitle,
          'artist_name': cleanArtist,
          'duration': track.durationSeconds.toString(),
        });
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          best = jsonDecode(res.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    // 2. Fallback to fuzzy search.
    if (best == null) {
      try {
        final q = '$cleanTitle $cleanArtist'.trim();
        final uri = Uri.https('lrclib.net', '/api/search', {'q': q});
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body) as List;
          if (list.isNotEmpty) {
            best = list.firstWhere(
              (e) => e['syncedLyrics'] != null,
              orElse: () => list.first,
            ) as Map<String, dynamic>;
          }
        }
      } catch (_) {}
    }

    final lines = <LyricLine>[];
    final synced = best?['syncedLyrics'] as String?;
    final plain = best?['plainLyrics'] as String?;

    if (synced != null && synced.trim().isNotEmpty) {
      lines.addAll(parseLrc(synced));
    } else if (plain != null && plain.trim().isNotEmpty) {
      for (final raw in plain.split('\n')) {
        final t = raw.trim();
        if (t.isNotEmpty) lines.add(LyricLine(text: t));
      }
    }

    _cache[track.id] = lines;
    return lines;
  }

  static List<LyricLine> parseLrc(String lrc) {
    final regex = RegExp(r'\[(\d+):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)');
    final out = <LyricLine>[];
    for (final rawLine in lrc.split('\n')) {
      final m = regex.firstMatch(rawLine.trim());
      if (m == null) continue;
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final fracStr = (m.group(3) ?? '0').padRight(3, '0').substring(0, 3);
      final ms = int.parse(fracStr);
      final text = m.group(4)?.trim() ?? '';
      if (text.isEmpty) continue;
      out.add(LyricLine(
        time: Duration(minutes: min, seconds: sec, milliseconds: ms),
        text: text,
      ));
    }
    return out;
  }
}
