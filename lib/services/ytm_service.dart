import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/app_settings.dart';
import '../models/track.dart';

class _CachedStream {
  final ResolvedAudioStream stream;
  final DateTime expiresAt;
  _CachedStream(this.stream, this.expiresAt);
}

class YtmService {
  static const _ytmSearchUrl =
      'https://music.youtube.com/youtubei/v1/search?prettyPrint=false';
  static const _ytmNextUrl =
      'https://music.youtube.com/youtubei/v1/next?prettyPrint=false';
  static const _ytmBrowseUrl =
      'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false';
  static const _ytPlayerUrl =
      'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';

  static const _androidUa =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
  static const _iosUa =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';

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
  final Map<String, _CachedStream> _videoCache = {};
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
    } catch (_) {}

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

  /// Fetches tracks from a public YouTube / YouTube Music playlist ID.
  Future<({String title, List<Track> tracks})> fetchPlaylist(
    String playlistId,
  ) async {
    final browseId =
        playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    final data = await _postInnertube(_ytmBrowseUrl, {'browseId': browseId});
    if (data == null) {
      throw Exception('Không thể tải playlist YouTube Music.');
    }

    String title = 'Playlist YouTube Music';
    final headers = <Map<String, dynamic>>[];
    _collectByKey(data, 'musicResponsiveHeaderRenderer', headers);
    _collectByKey(data, 'musicDetailHeaderRenderer', headers);
    if (headers.isNotEmpty) {
      final t = _runsText(headers.first['title']?['runs'] as List? ?? const []);
      if (t.isNotEmpty) title = t;
    }

    final items = <Map<String, dynamic>>[];
    _collectByKey(data, 'musicResponsiveListItemRenderer', items);
    final tracks = items
        .map(_parseResponsiveItem)
        .whereType<Track>()
        .toList(growable: false);
    return (title: title, tracks: tracks);
  }

  /// Resolves a verified audio/mp4 stream matching the selected [AudioQualityTier].
  Future<ResolvedAudioStream> resolveAudioStream(
    String videoId, {
    AudioQualityTier quality = AudioQualityTier.high,
  }) async {
    final cacheKey = '${videoId}_${quality.name}';
    final cached = _streamCache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.stream;
    }

    final errors = <String>[];

    final androidStream = await _resolveViaInnertubePlayer(
      videoId,
      clientPayload: {
        'clientName': 'ANDROID',
        'clientVersion': '20.10.38',
        'userAgent': _androidUa,
        'hl': 'en',
        'osName': 'Android',
        'osVersion': '11',
      },
      userAgent: _androidUa,
      quality: quality,
      errors: errors,
    );
    if (androidStream != null) {
      return _cacheAudio(cacheKey, androidStream);
    }

    final iosStream = await _resolveViaInnertubePlayer(
      videoId,
      clientPayload: {
        'clientName': 'IOS',
        'clientVersion': '20.10.4',
        'deviceMake': 'Apple',
        'deviceModel': 'iPhone16,2',
        'userAgent': _iosUa,
        'hl': 'en',
        'osName': 'IOS',
        'osVersion': '18.3.2.22D82',
      },
      userAgent: _iosUa,
      quality: quality,
      errors: errors,
    );
    if (iosStream != null) {
      return _cacheAudio(cacheKey, iosStream);
    }

    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 12));
      if (manifest.audioOnly.isNotEmpty) {
        final mp4Streams = manifest.audioOnly
            .where((s) => s.container.name == 'mp4' || s.container.name == 'm4a')
            .toList()
          ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        final chosen = mp4Streams.isNotEmpty
            ? (quality == AudioQualityTier.low ? mp4Streams.last : mp4Streams.first)
            : manifest.audioOnly.withHighestBitrate();
        final verified = await _probeStream(
          url: chosen.url.toString(),
          declaredLength: chosen.size.totalBytes,
          mimeType: chosen.container.name == 'webm' ? 'audio/webm' : 'audio/mp4',
          userAgent: _androidUa,
        );
        if (verified != null) {
          return _cacheAudio(cacheKey, verified);
        }
      }
      errors.add('YTExplode: không có luồng khả dụng');
    } catch (e) {
      errors.add('YTExplode: $e');
    }

    throw Exception(
      'Không lấy được luồng âm thanh (${errors.isNotEmpty ? errors.first : "lỗi mạng"})',
    );
  }

  /// Resolves a muxed MP4 video stream (itag=18, H.264 + AAC) for iOS AVPlayer Music Video mode.
  Future<ResolvedAudioStream> resolveVideoStream(String videoId) async {
    final cached = _videoCache[videoId];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.stream;
    }

    final clients = [
      (
        {
          'clientName': 'ANDROID',
          'clientVersion': '20.10.38',
          'userAgent': _androidUa,
          'hl': 'en',
          'osName': 'Android',
          'osVersion': '11',
        },
        _androidUa,
      ),
      (
        {
          'clientName': 'IOS',
          'clientVersion': '20.10.4',
          'deviceMake': 'Apple',
          'deviceModel': 'iPhone16,2',
          'userAgent': _iosUa,
          'hl': 'en',
          'osName': 'IOS',
          'osVersion': '18.3.2.22D82',
        },
        _iosUa,
      ),
    ];

    for (final (clientPayload, ua) in clients) {
      try {
        final res = await http
            .post(
              Uri.parse(_ytPlayerUrl),
              headers: {'Content-Type': 'application/json', 'User-Agent': ua},
              body: jsonEncode({
                'context': {'client': clientPayload},
                'videoId': videoId,
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final formats =
            (data['streamingData']?['formats'] as List?) ?? const [];
        final mp4Videos = formats
            .whereType<Map<String, dynamic>>()
            .where((f) {
              final mime = f['mimeType'] as String? ?? '';
              final url = f['url'] as String?;
              return mime.startsWith('video/mp4') && url != null && url.isNotEmpty;
            })
            .toList()
          ..sort((a, b) =>
              ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));

        for (final fmt in mp4Videos) {
          final url = fmt['url'] as String;
          final declaredLen = int.tryParse('${fmt['contentLength'] ?? ''}') ??
              int.tryParse(Uri.parse(url).queryParameters['clen'] ?? '') ??
              0;
          if (declaredLen > 0) {
            final resolved = ResolvedAudioStream(
              url: url,
              contentLength: declaredLen,
              mimeType: 'video/mp4',
              userAgent: ua,
            );
            _videoCache[videoId] = _CachedStream(
              resolved,
              DateTime.now().add(const Duration(minutes: 25)),
            );
            return resolved;
          }
          final verified = await _probeStream(
            url: url,
            declaredLength: declaredLen,
            mimeType: 'video/mp4',
            userAgent: ua,
          );
          if (verified != null) {
            _videoCache[videoId] = _CachedStream(
              verified,
              DateTime.now().add(const Duration(minutes: 25)),
            );
            return verified;
          }
        }
      } catch (_) {}
    }

    throw Exception('Bài hát này chưa hỗ trợ luồng Video MP4.');
  }

  ResolvedAudioStream _cacheAudio(String cacheKey, ResolvedAudioStream stream) {
    _streamCache[cacheKey] = _CachedStream(
      stream,
      DateTime.now().add(const Duration(minutes: 30)),
    );
    return stream;
  }

  Future<ResolvedAudioStream?> _resolveViaInnertubePlayer(
    String videoId, {
    required Map<String, dynamic> clientPayload,
    required String userAgent,
    required AudioQualityTier quality,
    required List<String> errors,
  }) async {
    final label = clientPayload['clientName'] as String? ?? 'PLAYER';
    try {
      final res = await http
          .post(
            Uri.parse(_ytPlayerUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': userAgent,
            },
            body: jsonEncode({
              'context': {'client': clientPayload},
              'videoId': videoId,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        errors.add('$label HTTP ${res.statusCode}');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['playabilityStatus']?['status'] as String?;
      if (status != 'OK') {
        final reason = data['playabilityStatus']?['reason'] as String? ?? status;
        errors.add('$label: $reason');
        return null;
      }

      final adaptive =
          (data['streamingData']?['adaptiveFormats'] as List?) ?? const [];
      final audioMp4 = adaptive
          .whereType<Map<String, dynamic>>()
          .where((f) {
            final mime = f['mimeType'] as String? ?? '';
            final url = f['url'] as String?;
            return mime.startsWith('audio/mp4') && url != null && url.isNotEmpty;
          })
          .toList();

      if (audioMp4.isEmpty) {
        errors.add('$label: không có luồng audio/mp4');
        return null;
      }

      audioMp4.sort((a, b) =>
          ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));

      final ordered = switch (quality) {
        AudioQualityTier.low => audioMp4.reversed.toList(),
        AudioQualityTier.medium => audioMp4.length > 1
            ? [audioMp4[audioMp4.length ~/ 2], ...audioMp4]
            : audioMp4,
        AudioQualityTier.high || AudioQualityTier.auto => audioMp4,
      };

      for (final fmt in ordered) {
        final url = fmt['url'] as String;
        final declaredLen = int.tryParse('${fmt['contentLength'] ?? ''}') ??
            int.tryParse(Uri.parse(url).queryParameters['clen'] ?? '') ??
            0;
        if (declaredLen > 0) {
          return ResolvedAudioStream(
            url: url,
            contentLength: declaredLen,
            mimeType: 'audio/mp4',
            userAgent: userAgent,
          );
        }
        final verified = await _probeStream(
          url: url,
          declaredLength: declaredLen,
          mimeType: 'audio/mp4',
          userAgent: userAgent,
        );
        if (verified != null) return verified;
      }
      errors.add('$label: CDN không phản hồi Range');
    } catch (e) {
      errors.add('$label: $e');
    }
    return null;
  }

  Future<ResolvedAudioStream?> _probeStream({
    required String url,
    required int declaredLength,
    required String mimeType,
    required String userAgent,
  }) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': userAgent,
          'Range': 'bytes=0-1',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200 && res.statusCode != 206) {
        return null;
      }

      int totalBytes = declaredLength;
      final contentRange = res.headers['content-range'];
      if (contentRange != null) {
        final slash = contentRange.lastIndexOf('/');
        if (slash != -1) {
          final parsed = int.tryParse(contentRange.substring(slash + 1).trim());
          if (parsed != null && parsed > 0) totalBytes = parsed;
        }
      }
      if (totalBytes <= 0) {
        final clenParam = Uri.parse(url).queryParameters['clen'];
        totalBytes = int.tryParse(clenParam ?? '') ?? 0;
      }
      if (totalBytes <= 0) return null;

      return ResolvedAudioStream(
        url: url,
        contentLength: totalBytes,
        mimeType: mimeType,
        userAgent: userAgent,
      );
    } catch (_) {
      return null;
    }
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
