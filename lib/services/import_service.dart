import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import '../models/user_profile.dart';
import 'ytm_service.dart';

class ImportProgress {
  final String stage;
  final int current;
  final int total;

  const ImportProgress({
    required this.stage,
    required this.current,
    required this.total,
  });

  double get fraction => total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
}

class ImportService {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  final YtmService ytm;

  ImportService({required this.ytm});

  /// Detects platform from a pasted playlist URL.
  static String? detectPlatform(String rawUrl) {
    final url = rawUrl.trim().toLowerCase();
    if (url.contains('open.spotify.com/playlist/') ||
        url.contains('spotify.com/embed/playlist/')) {
      return 'spotify';
    }
    if (url.contains('music.apple.com/') && url.contains('/playlist/')) {
      return 'apple_music';
    }
    if ((url.contains('youtube.com/') || url.contains('music.youtube.com/')) &&
        url.contains('list=')) {
      return 'youtube_music';
    }
    return null;
  }

  static String? extractSpotifyPlaylistId(String rawUrl) {
    final m = RegExp(r'playlist/([a-zA-Z0-9]+)').firstMatch(rawUrl);
    return m?.group(1);
  }

  static String? extractYouTubePlaylistId(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    final list = uri?.queryParameters['list'];
    if (list != null && list.isNotEmpty) return list;
    final m = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)').firstMatch(rawUrl);
    return m?.group(1);
  }

  Future<LocalPlaylist> importFromUrl(
    String rawUrl, {
    void Function(ImportProgress progress)? onProgress,
  }) async {
    final url = rawUrl.trim();
    final platform = detectPlatform(url);
    if (platform == null) {
      throw Exception(
        'Liên kết không hợp lệ. Hãy dán link playlist công khai từ Spotify, Apple Music hoặc YouTube Music.',
      );
    }

    if (platform == 'youtube_music') {
      return _importYouTubeMusic(url, onProgress: onProgress);
    }
    if (platform == 'spotify') {
      return _importSpotify(url, onProgress: onProgress);
    }
    return _importAppleMusic(url, onProgress: onProgress);
  }

  Future<LocalPlaylist> _importYouTubeMusic(
    String url, {
    void Function(ImportProgress)? onProgress,
  }) async {
    final listId = extractYouTubePlaylistId(url);
    if (listId == null) {
      throw Exception('Không tìm thấy mã playlist YouTube Music.');
    }
    onProgress?.call(const ImportProgress(
      stage: 'Đang tải danh sách từ YouTube Music...',
      current: 0,
      total: 1,
    ));
    final result = await ytm.fetchPlaylist(listId);
    if (result.tracks.isEmpty) {
      throw Exception('Playlist trống hoặc đang ở chế độ riêng tư.');
    }
    onProgress?.call(ImportProgress(
      stage: 'Hoàn tất nhập ${result.tracks.length} bài hát!',
      current: result.tracks.length,
      total: result.tracks.length,
    ));
    return LocalPlaylist(
      id: 'ytm_${DateTime.now().millisecondsSinceEpoch}',
      name: result.title,
      tracks: result.tracks,
      createdAt: DateTime.now().toIso8601String(),
      sourcePlatform: 'youtube_music',
    );
  }

  Future<LocalPlaylist> _importSpotify(
    String url, {
    void Function(ImportProgress)? onProgress,
  }) async {
    final playlistId = extractSpotifyPlaylistId(url);
    if (playlistId == null) {
      throw Exception('Không nhận diện được ID playlist Spotify.');
    }

    onProgress?.call(const ImportProgress(
      stage: 'Đang đọc playlist Spotify...',
      current: 0,
      total: 1,
    ));

    final embedUrl = 'https://open.spotify.com/embed/playlist/$playlistId';
    final res = await http
        .get(Uri.parse(embedUrl), headers: {'User-Agent': _ua})
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Không thể truy cập playlist Spotify (HTTP ${res.statusCode}).');
    }

    final match = RegExp(
      r'<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>',
    ).firstMatch(res.body);
    if (match == null) {
      throw Exception('Không trích xuất được danh sách bài hát Spotify.');
    }

    final json = jsonDecode(match.group(1)!) as Map<String, dynamic>;
    final entity = json['props']?['pageProps']?['state']?['data']?['entity']
        as Map<String, dynamic>?;
    final name = (entity?['name'] as String?)?.trim();
    final trackList = (entity?['trackList'] as List?) ?? const [];
    if (trackList.isEmpty) {
      throw Exception('Playlist Spotify trống hoặc không công khai.');
    }

    final queries = <(String, String)>[];
    for (final item in trackList.take(40)) {
      if (item is! Map) continue;
      final title = (item['title'] as String? ?? '').trim();
      final artist = (item['subtitle'] as String? ?? '').trim();
      if (title.isNotEmpty) queries.add((title, artist));
    }

    final matched = await _matchQueriesOnYtm(
      queries,
      platformName: 'Spotify',
      onProgress: onProgress,
    );
    if (matched.isEmpty) {
      throw Exception('Không khớp được bài hát nào trên YouTube Music.');
    }

    return LocalPlaylist(
      id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
      name: (name != null && name.isNotEmpty) ? name : 'Spotify Import',
      tracks: matched,
      createdAt: DateTime.now().toIso8601String(),
      sourcePlatform: 'spotify',
    );
  }

  Future<LocalPlaylist> _importAppleMusic(
    String url, {
    void Function(ImportProgress)? onProgress,
  }) async {
    onProgress?.call(const ImportProgress(
      stage: 'Đang đọc playlist Apple Music...',
      current: 0,
      total: 1,
    ));

    final res = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': _ua, 'Accept-Language': 'en-US,en;q=0.9'},
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw Exception('Không thể mở playlist Apple Music (HTTP ${res.statusCode}).');
    }

    String title = 'Apple Music Import';
    final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(res.body);
    if (titleMatch != null) {
      final clean = titleMatch
          .group(1)!
          .replaceAll(RegExp(r'\s*[-–|]\s*Apple Music.*', caseSensitive: false), '')
          .trim();
      if (clean.isNotEmpty) title = clean;
    }

    final queries = <(String, String)>[];
    // 1. Try JSON-LD music-playlist schema first.
    final ldMatch = RegExp(
      r'<script[^>]*type="application/ld\+json"[^>]*>([\s\S]*?)</script>',
    ).allMatches(res.body);
    for (final m in ldMatch) {
      try {
        final obj = jsonDecode(m.group(1)!);
        if (obj is Map && obj['track'] is List) {
          if (obj['name'] is String && (obj['name'] as String).isNotEmpty) {
            title = obj['name'] as String;
          }
          for (final t in (obj['track'] as List).take(40)) {
            if (t is! Map) continue;
            final songName = (t['name'] as String? ?? '').trim();
            final byArtist = t['byArtist'];
            final artistName = byArtist is Map
                ? (byArtist['name'] as String? ?? '')
                : (byArtist is List && byArtist.isNotEmpty && byArtist.first is Map
                    ? (byArtist.first['name'] as String? ?? '')
                    : '');
            if (songName.isNotEmpty) queries.add((songName, artistName));
          }
        }
      } catch (_) {}
    }

    // 2. Fallback: extract song names from Apple Music song URLs in meta tags.
    if (queries.isEmpty) {
      final metaMatches = RegExp(
        r'<meta[^>]*name="music:song"[^>]*content="([^"]+)"',
      ).allMatches(res.body);
      for (final m in metaMatches.take(35)) {
        final songUrl = m.group(1) ?? '';
        final segs = Uri.tryParse(songUrl)?.pathSegments ?? const [];
        if (segs.length >= 3) {
          final slug = Uri.decodeComponent(segs[segs.length - 2])
              .replaceAll('-', ' ')
              .trim();
          if (slug.isNotEmpty) queries.add((slug, ''));
        }
      }
    }

    if (queries.isEmpty) {
      throw Exception(
        'Apple Music không trả về danh sách bài hát công khai cho link này.',
      );
    }

    final matched = await _matchQueriesOnYtm(
      queries,
      platformName: 'Apple Music',
      onProgress: onProgress,
    );
    if (matched.isEmpty) {
      throw Exception('Không khớp được bài hát nào trên YouTube Music.');
    }

    return LocalPlaylist(
      id: 'am_${DateTime.now().millisecondsSinceEpoch}',
      name: title,
      tracks: matched,
      createdAt: DateTime.now().toIso8601String(),
      sourcePlatform: 'apple_music',
    );
  }

  Future<List<Track>> _matchQueriesOnYtm(
    List<(String, String)> queries, {
    required String platformName,
    void Function(ImportProgress)? onProgress,
  }) async {
    final matched = <Track>[];
    final seenIds = <String>{};
    final total = queries.length;

    for (int i = 0; i < total; i++) {
      final (title, artist) = queries[i];
      onProgress?.call(ImportProgress(
        stage: 'Đang ghép bài $platformName (${i + 1}/$total): $title',
        current: i + 1,
        total: total,
      ));
      try {
        final q = artist.isNotEmpty ? '$title $artist' : title;
        final results = await ytm.searchSongs(q);
        if (results.isNotEmpty && seenIds.add(results.first.id)) {
          matched.add(results.first);
        }
      } catch (_) {}
    }
    return matched;
  }
}
