import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';

class _CachedStream {
  final String url;
  final DateTime expiresAt;
  _CachedStream(this.url, this.expiresAt);
}

class YtmService {
  static const _ytmSearchUrl =
      'https://music.youtube.com/youtubei/v1/search?prettyPrint=false';
  static const _ytmNextUrl =
      'https://music.youtube.com/youtubei/v1/next?prettyPrint=false';

  static const _headers = {
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Origin': 'https://music.youtube.com',
  };

  static const Map<String, String> moodQueries = {
    'trending': 'nhạc trẻ V-Pop thịnh hành mới nhất',
    'chill': 'nhạc chill nhẹ nhàng lofi acoustic',
    'usuk': 'Billboard Hot 100 pop hits',
    'ballad': 'nhạc ballad buồn hay nhất',
    'lofi': 'lofi beats to study relax',
  };

  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, _CachedStream> _streamCache = {};
  final Map<String, List<Track>> _moodCache = {};

  Future<Map<String, dynamic>?> _postInnertube(
    String url,
    Map<String, dynamic> body,
  ) async {
    final res = await http
        .post(
          Uri.parse(url),
          headers: _headers,
          body: jsonEncode({
            'context': {
              'client': {
                'clientName': 'WEB_REMIX',
                'clientVersion': '1.20250101.01.00',
                'hl': 'vi',
                'gl': 'VN',
              },
            },
            ...body,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Track>> fetchMoodTracks(String moodKey, {bool force = false}) async {
    if (!force && _moodCache.containsKey(moodKey)) {
      return _moodCache[moodKey]!;
    }
    final query = moodQueries[moodKey] ?? moodQueries['trending']!;
    final tracks = await searchSongs(query);
    if (tracks.isNotEmpty) {
      _moodCache[moodKey] = tracks;
    }
    return tracks;
  }

  Future<List<Track>> searchSongs(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // Try YouTube Music InnerTube "Songs" filter first for clean square artwork & metadata.
    try {
      final data = await _postInnertube(_ytmSearchUrl, {
        'query': trimmed,
        'params': 'EgWKAQIIAWoMEAMQBBAJEAoQBRAV',
      });
      if (data != null) {
        final items = <Map<String, dynamic>>[];
        _collectByKey(data, 'musicResponsiveListItemRenderer', items);
        final parsed = items
            .map(_parseResponsiveItem)
            .whereType<Track>()
            .toList(growable: false);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {
      // Fall through to YoutubeExplode search below.
    }

    // Fallback to standard YouTube search via youtube_explode_dart.
    final videos = await _yt.search.search(trimmed);
    return videos
        .where((v) => v.duration != null && v.duration!.inSeconds > 15)
        .take(20)
        .map(
          (v) => Track(
            id: v.id.value,
            title: v.title,
            artist: v.author,
            thumbnailUrl: v.thumbnails.highResUrl,
            durationSeconds: v.duration?.inSeconds ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<List<Track>> fetchUpNext(String videoId) async {
    try {
      final data = await _postInnertube(_ytmNextUrl, {
        'videoId': videoId,
        'playlistId': 'RDAMVM$videoId',
        'isAudioOnly': true,
      });
      if (data == null) return [];
      final items = <Map<String, dynamic>>[];
      _collectByKey(data, 'playlistPanelVideoRenderer', items);
      return items
          .map(_parsePlaylistPanelItem)
          .whereType<Track>()
          .where((t) => t.id != videoId)
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  /// Resolves a direct audio stream URL compatible with iOS AVPlayer (MP4/AAC preferred).
  Future<String> resolveAudioUrl(String videoId) async {
    final cached = _streamCache[videoId];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.url;
    }

    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    if (manifest.audioOnly.isEmpty) {
      throw Exception('Không tìm thấy luồng âm thanh cho bài hát này.');
    }

    // iOS AVPlayer natively decodes MP4/M4A (AAC), whereas WebM/Opus fails on iOS.
    final mp4Streams = manifest.audioOnly
        .where((s) => s.container.name == 'mp4' || s.container.name == 'm4a');
    final chosen = mp4Streams.isNotEmpty
        ? mp4Streams.withHighestBitrate()
        : manifest.audioOnly.withHighestBitrate();

    final url = chosen.url.toString();
    _streamCache[videoId] = _CachedStream(
      url,
      DateTime.now().add(const Duration(minutes: 30)),
    );
    return url;
  }

  void _collectByKey(
    dynamic node,
    String targetKey,
    List<Map<String, dynamic>> out,
  ) {
    if (node is Map<String, dynamic>) {
      if (node.containsKey(targetKey) && node[targetKey] is Map<String, dynamic>) {
        out.add(node[targetKey] as Map<String, dynamic>);
      }
      for (final value in node.values) {
        _collectByKey(value, targetKey, out);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectByKey(item, targetKey, out);
      }
    }
  }

  Track? _parseResponsiveItem(Map<String, dynamic> item) {
    final videoId = item['playlistItemData']?['videoId'] as String? ??
        item['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
                ?['musicPlayButtonRenderer']?['playNavigationEndpoint']
            ?['watchEndpoint']?['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) return null;

    final flexColumns = item['flexColumns'] as List? ?? const [];
    final title = _runsText(_flexRuns(flexColumns, 0));
    if (title.isEmpty) return null;

    final subtitleRuns = _flexRuns(flexColumns, 1);
    final subtitleParts = subtitleRuns
        .map((r) => (r['text'] as String? ?? '').trim())
        .where((t) => t.isNotEmpty && t != '•' && t != '·' && t != ',')
        .toList();

    final artist = subtitleParts.isNotEmpty ? subtitleParts.first : 'YouTube Music';
    int durationSeconds = 0;
    for (final part in subtitleParts.reversed) {
      final parsed = _parseDuration(part);
      if (parsed > 0) {
        durationSeconds = parsed;
        break;
      }
    }

    final thumbs = item['thumbnail']?['musicThumbnailRenderer']?['thumbnail']
        ?['thumbnails'] as List?;
    final thumbUrl =
        thumbs != null && thumbs.isNotEmpty ? (thumbs.last['url'] as String? ?? '') : '';

    return Track(
      id: videoId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbUrl,
      durationSeconds: durationSeconds,
    );
  }

  Track? _parsePlaylistPanelItem(Map<String, dynamic> item) {
    final videoId = item['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) return null;

    final title = _runsText(item['title']?['runs'] as List? ?? const []);
    if (title.isEmpty) return null;

    final artistRuns = item['shortBylineText']?['runs'] as List? ??
        item['longBylineText']?['runs'] as List? ??
        const [];
    final artist = _runsText(artistRuns).split('•').first.trim();
    final lengthText = _runsText(item['lengthText']?['runs'] as List? ?? const []);
    final thumbs = item['thumbnail']?['thumbnails'] as List?;
    final thumbUrl =
        thumbs != null && thumbs.isNotEmpty ? (thumbs.last['url'] as String? ?? '') : '';

    return Track(
      id: videoId,
      title: title,
      artist: artist.isNotEmpty ? artist : 'YouTube Music',
      thumbnailUrl: thumbUrl,
      durationSeconds: _parseDuration(lengthText),
    );
  }

  List<dynamic> _flexRuns(List<dynamic> flexColumns, int index) {
    if (index >= flexColumns.length) return const [];
    return flexColumns[index]?['musicResponsiveListItemFlexColumnRenderer']
            ?['text']?['runs'] as List? ??
        const [];
  }

  String _runsText(List<dynamic> runs) =>
      runs.map((r) => r['text'] as String? ?? '').join('').trim();

  int _parseDuration(String text) {
    final match = RegExp(r'^(\d+:)?\d+:\d{2}$').firstMatch(text.trim());
    if (match == null) return 0;
    final parts = text.trim().split(':').map(int.tryParse).toList();
    if (parts.any((p) => p == null)) return 0;
    if (parts.length == 2) return parts[0]! * 60 + parts[1]!;
    if (parts.length == 3) return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
    return 0;
  }

  void dispose() => _yt.close();
}
