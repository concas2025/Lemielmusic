import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/track.dart';

class LyricsService {
  final Map<String, LyricsResult> _cache = {};

  Future<LyricsResult> fetchLyrics(
    Track track, {
    List<String>? providers,
    String? forceProvider,
  }) async {
    if (forceProvider != null) {
      final cacheKey = '${track.id}::$forceProvider';
      if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;
      final res = await _queryProvider(forceProvider, track);
      if (res.isNotEmpty) _cache[cacheKey] = res;
      return res;
    }

    final order = (providers != null && providers.isNotEmpty)
        ? providers
        : AppSettings.defaultLyricsProviders;
    final cacheKey = '${track.id}::${order.join(',')}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    LyricsResult? plainFallback;
    for (final providerId in order) {
      final res = await _queryProvider(providerId, track);
      if (res.isEmpty) continue;
      if (res.isSynced) {
        _cache[cacheKey] = res;
        return res;
      }
      plainFallback ??= res;
    }

    final finalResult = plainFallback ?? LyricsResult.empty;
    if (finalResult.isNotEmpty) {
      _cache[cacheKey] = finalResult;
    }
    return finalResult;
  }

  Future<LyricsResult> _queryProvider(String providerId, Track track) async {
    return switch (providerId) {
      'lrclib' => _fetchLrcLib(track),
      'betterlyrics' => _fetchBetterLyrics(track),
      'ytm' => _fetchYtmLyrics(track),
      'lyricsovh' => _fetchLyricsOvh(track),
      _ => Future.value(LyricsResult.empty),
    };
  }

  (String, String) _cleanQuery(Track track) {
    final cleanTitle = track.title
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
        .replaceAll(RegExp(r'\s*[-|].*Official.*', caseSensitive: false), '')
        .trim();
    final cleanArtist = track.artist.split(RegExp(r'[,&•]')).first.trim();
    return (cleanTitle.isNotEmpty ? cleanTitle : track.title, cleanArtist);
  }

  Future<LyricsResult> _fetchLrcLib(Track track) async {
    final (title, artist) = _cleanQuery(track);
    Map<String, dynamic>? best;

    if (track.durationSeconds > 0 && title.isNotEmpty) {
      try {
        final uri = Uri.https('lrclib.net', '/api/get', {
          'track_name': title,
          'artist_name': artist,
          'duration': track.durationSeconds.toString(),
        });
        final res = await http.get(uri).timeout(const Duration(seconds: 7));
        if (res.statusCode == 200) {
          best = jsonDecode(res.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    if (best == null) {
      try {
        final q = '$title $artist'.trim();
        final uri = Uri.https('lrclib.net', '/api/search', {'q': q});
        final res = await http.get(uri).timeout(const Duration(seconds: 7));
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
      lines.addAll(_parsePlain(plain));
    }

    return LyricsResult(
      lines: lines,
      providerId: 'lrclib',
      providerName: 'LrcLib',
    );
  }

  Future<LyricsResult> _fetchBetterLyrics(Track track) async {
    final (title, artist) = _cleanQuery(track);
    try {
      final params = <String, String>{'s': title, 'a': artist};
      if (track.durationSeconds > 0) {
        params['d'] = track.durationSeconds.toString();
      }
      final uri = Uri.https('lyrics-api.boidu.dev', '/getLyrics', params);
      final res = await http.get(uri).timeout(const Duration(seconds: 7));
      if (res.statusCode != 200) return LyricsResult.empty;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final ttml = json['ttml'] as String?;
      if (ttml == null || ttml.isEmpty) return LyricsResult.empty;
      final lines = parseTtml(ttml);
      return LyricsResult(
        lines: lines,
        providerId: 'betterlyrics',
        providerName: 'BetterLyrics (TTML)',
      );
    } catch (_) {
      return LyricsResult.empty;
    }
  }

  Future<LyricsResult> _fetchYtmLyrics(Track track) async {
    if (track.id.isEmpty) return LyricsResult.empty;
    try {
      const ctx = {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20250101.01.00',
          'hl': 'vi',
          'gl': 'VN',
        },
      };
      const headers = {
        'Content-Type': 'application/json',
        'Origin': 'https://music.youtube.com',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      };
      final r1 = await http
          .post(
            Uri.parse('https://music.youtube.com/youtubei/v1/next?prettyPrint=false'),
            headers: headers,
            body: jsonEncode({'context': ctx, 'videoId': track.id}),
          )
          .timeout(const Duration(seconds: 7));
      if (r1.statusCode != 200) return LyricsResult.empty;
      final j1 = jsonDecode(r1.body) as Map<String, dynamic>;
      final tabs = j1['contents']?['singleColumnMusicWatchNextResultsRenderer']
              ?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs']
          as List?;
      String? browseId;
      for (final t in tabs ?? const []) {
        final id = t?['tabRenderer']?['endpoint']?['browseEndpoint']?['browseId']
            as String?;
        if (id != null && id.startsWith('MPLYt')) {
          browseId = id;
          break;
        }
      }
      if (browseId == null) return LyricsResult.empty;

      final r2 = await http
          .post(
            Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false'),
            headers: headers,
            body: jsonEncode({'context': ctx, 'browseId': browseId}),
          )
          .timeout(const Duration(seconds: 7));
      if (r2.statusCode != 200) return LyricsResult.empty;
      final j2 = jsonDecode(r2.body) as Map<String, dynamic>;
      final sec = j2['contents']?['sectionListRenderer']?['contents']?[0]
          ?['musicDescriptionShelfRenderer'];
      final runs = sec?['description']?['runs'] as List? ?? const [];
      final rawText = runs.map((r) => r['text'] as String? ?? '').join('');
      final lines = _parsePlain(rawText);
      return LyricsResult(
        lines: lines,
        providerId: 'ytm',
        providerName: 'YouTube Music',
      );
    } catch (_) {
      return LyricsResult.empty;
    }
  }

  Future<LyricsResult> _fetchLyricsOvh(Track track) async {
    final (title, artist) = _cleanQuery(track);
    if (title.isEmpty || artist.isEmpty) return LyricsResult.empty;
    try {
      final uri = Uri.https(
        'api.lyrics.ovh',
        '/v1/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return LyricsResult.empty;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final lyrics = json['lyrics'] as String?;
      if (lyrics == null || lyrics.trim().isEmpty) return LyricsResult.empty;
      return LyricsResult(
        lines: _parsePlain(lyrics),
        providerId: 'lyricsovh',
        providerName: 'Lyrics.ovh',
      );
    } catch (_) {
      return LyricsResult.empty;
    }
  }

  static List<LyricLine> _parsePlain(String plain) {
    final out = <LyricLine>[];
    for (final raw in plain.split('\n')) {
      final t = raw.trim();
      if (t.isNotEmpty) out.add(LyricLine(text: t));
    }
    return out;
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

  /// Parses Apple Music / BetterLyrics TTML `<p begin="..." ...>...</p>` tags.
  static List<LyricLine> parseTtml(String ttml) {
    final pRegex = RegExp(
      r'<p\b[^>]*\bbegin="([^"]+)"[^>]*>([\s\S]*?)</p>',
      caseSensitive: false,
    );
    final tagRegex = RegExp(r'<[^>]+>');
    final out = <LyricLine>[];

    for (final m in pRegex.allMatches(ttml)) {
      final begin = m.group(1)!;
      final inner = m.group(2)!
          .replaceAll(tagRegex, ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&apos;', "'")
          .replaceAll('&#39;', "'")
          .replaceAll('&quot;', '"')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (inner.isEmpty) continue;
      final dur = _parseTtmlTimestamp(begin);
      out.add(LyricLine(time: dur, text: inner));
    }
    return out;
  }

  static Duration? _parseTtmlTimestamp(String raw) {
    final s = raw.trim();
    if (s.endsWith('s')) {
      final secs = double.tryParse(s.substring(0, s.length - 1));
      if (secs != null) return Duration(milliseconds: (secs * 1000).round());
    }
    final parts = s.split(':');
    if (parts.length == 2) {
      final min = int.tryParse(parts[0]) ?? 0;
      final sec = double.tryParse(parts[1]) ?? 0;
      return Duration(milliseconds: min * 60000 + (sec * 1000).round());
    }
    if (parts.length == 3) {
      final hr = int.tryParse(parts[0]) ?? 0;
      final min = int.tryParse(parts[1]) ?? 0;
      final sec = double.tryParse(parts[2]) ?? 0;
      return Duration(
        milliseconds: hr * 3600000 + min * 60000 + (sec * 1000).round(),
      );
    }
    final secs = double.tryParse(s);
    if (secs != null) return Duration(milliseconds: (secs * 1000).round());
    return null;
  }
}
