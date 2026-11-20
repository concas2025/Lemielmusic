import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  static const _ytVisitorUrl =
      'https://www.youtube.com/youtubei/v1/visitor_id?prettyPrint=false';

  static const _visionOsUa =
      'com.google.visionos.youtube/1.04(RealityDevice17,1; U; CPU visionOS 26_6_0 like Mac OS X; US)';
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

  /// Offset just beyond YouTube's 1.00 MiB (1,048,576 bytes) unverified-client cutoff.
  static const int _past1MiBOffset = 1150000;

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

  String? _visionVisitorData;
  DateTime? _visionVisitorFetchedAt;

  void invalidateStreamCache(String videoId) {
    _streamCache.removeWhere((k, _) => k.startsWith('${videoId}_'));
    _videoCache.remove(videoId);
    debugPrint('[LemielAudio] Invalidated cached stream URLs for $videoId');
  }

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

  Future<String?> _getVisionVisitorData({bool forceRefresh = false}) async {
    final fresh = !forceRefresh &&
        _visionVisitorData != null &&
        _visionVisitorFetchedAt != null &&
        DateTime.now().difference(_visionVisitorFetchedAt!) <
            const Duration(minutes: 45);
    if (fresh) return _visionVisitorData;

    try {
      final res = await http
          .post(
            Uri.parse(_ytVisitorUrl),
            headers: const {
              'Content-Type': 'application/json',
              'User-Agent': _visionOsUa,
              'X-YouTube-Client-Name': '101',
              'X-YouTube-Client-Version': '1.04',
            },
            body: jsonEncode({
              'context': {
                'client': {
                  'clientName': 'VISIONOS',
                  'clientVersion': '1.04',
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final v = data['responseContext']?['visitorData'] as String?;
        if (v != null && v.isNotEmpty) {
          _visionVisitorData = v;
          _visionVisitorFetchedAt = DateTime.now();
          return v;
        }
      }
    } catch (e) {
      debugPrint('[LemielAudio] VISIONOS visitor_id fetch failed: $e');
    }
    return _visionVisitorData;
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

  /// Resolves a verified full-length audio stream that works beyond YouTube's 1 MiB
  /// cutoff (~1:05–1:30 of audio).
  ///
  /// Order:
  /// 1. VISIONOS adaptive `audio/mp4` (itag=140/139) with fresh visitorData — verified
  ///    past 1 MiB all the way to EOF with zero 403.
  /// 2. ANDROID progressive `video/mp4` (itag=18, AAC stereo) — also verified past 1 MiB
  ///    to EOF if VISIONOS is unavailable for a specific track.
  /// 3. ANDROID / IOS adaptive `audio/mp4` (only accepted if past-1MiB probe succeeds).
  /// 4. YoutubeExplode fallback.
  Future<ResolvedAudioStream> resolveAudioStream(
    String videoId, {
    AudioQualityTier quality = AudioQualityTier.high,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${videoId}_${quality.name}';
    if (!forceRefresh) {
      final cached = _streamCache[cacheKey];
      if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
        return cached.stream;
      }
    }

    final errors = <String>[];

    // 1. Primary: VISIONOS adaptive audio/mp4 (no 1 MiB 403 cap).
    for (int attempt = 0; attempt < 2; attempt++) {
      final visitor = await _getVisionVisitorData(forceRefresh: attempt > 0);
      final visionStream = await _resolveViaInnertubePlayer(
        videoId,
        clientPayload: {
          'clientName': 'VISIONOS',
          'clientVersion': '1.04',
          'clientScreen': 'WATCH',
          'platform': 'MOBILE',
          'osName': 'visionOS',
          'osVersion': '26.6.0.23O770',
          'deviceMake': 'Apple',
          'deviceModel': 'RealityDevice17,1',
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
          'visitorData': ?visitor,
        },
        userAgent: _visionOsUa,
        extraHeaders: {
          'X-YouTube-Client-Name': '101',
          'X-YouTube-Client-Version': '1.04',
          'X-Goog-Visitor-Id': ?visitor,
        },
        quality: quality,
        verifyPast1MiB: true,
        errors: errors,
      );
      if (visionStream != null) {
        debugPrint(
          '[LemielAudio] Resolved $videoId via VISIONOS (${visionStream.mimeType}, ${(visionStream.contentLength / 1048576).toStringAsFixed(2)} MB)',
        );
        return _cacheAudio(cacheKey, visionStream);
      }
      if (visitor == null) break;
    }

    // 2. Reliable full-length fallback: ANDROID progressive MP4 (itag=18, AAC audio)
    //    verified past 1 MiB to EOF when VISIONOS adaptive is unavailable.
    final progressiveFallback = await _resolveProgressiveFallback(
      videoId,
      errors: errors,
    );
    if (progressiveFallback != null) {
      debugPrint(
        '[LemielAudio] Resolved $videoId via ANDROID progressive MP4 fallback (${(progressiveFallback.contentLength / 1048576).toStringAsFixed(2)} MB)',
      );
      return _cacheAudio(cacheKey, progressiveFallback);
    }

    // 3. ANDROID adaptive (must pass past-1MiB probe so we never hit 1:30 403).
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
      verifyPast1MiB: true,
      errors: errors,
    );
    if (androidStream != null) {
      return _cacheAudio(cacheKey, androidStream);
    }

    // 4. IOS adaptive (must pass past-1MiB probe).
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
      verifyPast1MiB: true,
      errors: errors,
    );
    if (iosStream != null) {
      return _cacheAudio(cacheKey, iosStream);
    }

    // 5. Last resort: youtube_explode_dart.
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
          verifyPast1MiB: false,
        );
        if (verified != null) {
          return _cacheAudio(cacheKey, verified);
        }
      }
      errors.add('YTExplode: không có luồng khả dụng');
    } catch (e) {
      errors.add('YTExplode: $e');
    }

    debugPrint('[LemielAudio] All audio resolvers failed for $videoId: $errors');
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

    final errors = <String>[];
    final stream = await _resolveProgressiveFallback(videoId, errors: errors);
    if (stream != null) {
      _videoCache[videoId] = _CachedStream(
        stream,
        DateTime.now().add(const Duration(minutes: 25)),
      );
      return stream;
    }

    throw Exception('Bài hát này chưa hỗ trợ luồng Video MP4.');
  }

  Future<ResolvedAudioStream?> _resolveProgressiveFallback(
    String videoId, {
    required List<String> errors,
  }) async {
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
                'contentCheckOk': true,
                'racyCheckOk': true,
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
              ((a['bitrate'] as num?) ?? 0).compareTo((b['bitrate'] as num?) ?? 0));

        for (final fmt in mp4Videos) {
          final url = fmt['url'] as String;
          final declaredLen = int.tryParse('${fmt['contentLength'] ?? ''}') ??
              int.tryParse(Uri.parse(url).queryParameters['clen'] ?? '') ??
              0;
          final verified = await _probeStream(
            url: url,
            declaredLength: declaredLen,
            mimeType: 'video/mp4',
            userAgent: ua,
            verifyPast1MiB: true,
          );
          if (verified != null) return verified;
        }
      } catch (e) {
        errors.add('PROG: $e');
      }
    }
    return null;
  }

  ResolvedAudioStream _cacheAudio(String cacheKey, ResolvedAudioStream stream) {
    _streamCache[cacheKey] = _CachedStream(
      stream,
      DateTime.now().add(const Duration(minutes: 25)),
    );
    return stream;
  }

  Future<ResolvedAudioStream?> _resolveViaInnertubePlayer(
    String videoId, {
    required Map<String, dynamic> clientPayload,
    required String userAgent,
    Map<String, String> extraHeaders = const {},
    required AudioQualityTier quality,
    required bool verifyPast1MiB,
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
              ...extraHeaders,
            },
            body: jsonEncode({
              'context': {'client': clientPayload},
              'videoId': videoId,
              'contentCheckOk': true,
              'racyCheckOk': true,
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
        final verified = await _probeStream(
          url: url,
          declaredLength: declaredLen,
          mimeType: 'audio/mp4',
          userAgent: userAgent,
          verifyPast1MiB: verifyPast1MiB,
        );
        if (verified != null) return verified;
      }
      errors.add('$label: CDN chặn 403 sau 1MB hoặc không phản hồi Range');
    } catch (e) {
      errors.add('$label: $e');
    }
    return null;
  }

  /// Proves the CDN URL serves Range requests AND does not hit YouTube's 1.00 MiB
  /// 403 cap (the root cause of the ~1:30 playback freeze).
  Future<ResolvedAudioStream?> _probeStream({
    required String url,
    required int declaredLength,
    required String mimeType,
    required String userAgent,
    required bool verifyPast1MiB,
  }) async {
    try {
      int totalBytes = declaredLength;
      if (totalBytes <= 0) {
        totalBytes =
            int.tryParse(Uri.parse(url).queryParameters['clen'] ?? '') ?? 0;
      }

      // If length is unknown or short (<= 1.15 MB), probe bytes=0-1.
      // Otherwise probe bytes=1150000-1150001 in ONE single round-trip to both
      // extract exact Content-Range total AND prove no 1 MiB 403 cutoff!
      final probeStart =
          (verifyPast1MiB && totalBytes > _past1MiBOffset + 2)
              ? _past1MiBOffset
              : 0;
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': userAgent,
          'Range': 'bytes=$probeStart-${probeStart + 1}',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200 && res.statusCode != 206) {
        debugPrint(
          '[LemielAudio] Probe failed HTTP ${res.statusCode} at byte $probeStart',
        );
        return null;
      }

      final contentRange = res.headers['content-range'];
      if (contentRange != null) {
        final slash = contentRange.lastIndexOf('/');
        if (slash != -1) {
          final parsed = int.tryParse(contentRange.substring(slash + 1).trim());
          if (parsed != null && parsed > 0) totalBytes = parsed;
        }
      }
      if (totalBytes <= 0) return null;

      // If we started at 0 (because length wasn't declared) and discovered the
      // file exceeds 1.15 MB, run the past-1MiB verification now.
      if (verifyPast1MiB && probeStart == 0 && totalBytes > _past1MiBOffset + 2) {
        final midRes = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': userAgent,
            'Range': 'bytes=$_past1MiBOffset-${_past1MiBOffset + 1}',
          },
        ).timeout(const Duration(seconds: 6));
        if (midRes.statusCode != 200 && midRes.statusCode != 206) {
          debugPrint(
            '[LemielAudio] Rejected 1MiB-capped stream (HTTP ${midRes.statusCode} at $_past1MiBOffset)',
          );
          return null;
        }
      }

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
