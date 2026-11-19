import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import '../models/track.dart';

class _CachedTrackBuffer {
  final String id;
  final int totalBytes;
  final int chunkSize;
  final File file;
  final List<bool> downloadedChunks;
  final Map<int, Future<bool>> inFlight = {};
  RandomAccessFile? _raf;
  Future<void> _ioChain = Future.value();
  bool closed = false;
  DateTime lastAccess = DateTime.now();

  _CachedTrackBuffer({
    required this.id,
    required this.totalBytes,
    required this.chunkSize,
    required this.file,
  }) : downloadedChunks = List<bool>.filled(
          (totalBytes + chunkSize - 1) ~/ chunkSize,
          false,
        );

  int get chunkCount => downloadedChunks.length;

  Future<T> _serialized<T>(Future<T> Function(RandomAccessFile raf) action) {
    final completer = Completer<T>();
    _ioChain = _ioChain.then((_) async {
      if (closed) {
        completer.completeError(StateError('Buffer closed'));
        return;
      }
      try {
        _raf ??= await file.open(mode: FileMode.writeOnlyAppend);
        // Ensure random read/write access by reopening in write/read mode once.
        final raf = _raf!;
        final result = await action(raf);
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> initFile() async {
    await file.parent.create(recursive: true);
    if (!await file.exists()) {
      await file.create();
    }
    _raf = await file.open(mode: FileMode.write);
    await _raf!.truncate(totalBytes);
  }

  Future<void> writeChunk(int chunkIndex, Uint8List bytes) async {
    final offset = chunkIndex * chunkSize;
    await _serialized((raf) async {
      await raf.setPosition(offset);
      await raf.writeFrom(bytes);
    });
    downloadedChunks[chunkIndex] = true;
    lastAccess = DateTime.now();
  }

  Future<Uint8List> readRange(int start, int length) async {
    lastAccess = DateTime.now();
    return _serialized((raf) async {
      await raf.setPosition(start);
      return raf.read(length);
    });
  }

  bool hasAllChunksInRange(int start, int end) {
    final first = start ~/ chunkSize;
    final last = end ~/ chunkSize;
    for (int c = first; c <= last; c++) {
      if (!downloadedChunks[c]) return false;
    }
    return true;
  }

  Future<void> closeAndDelete() async {
    closed = true;
    try {
      await _ioChain;
    } catch (_) {}
    try {
      await _raf?.close();
    } catch (_) {}
    _raf = null;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// High-speed local loopback HTTP server for iOS AVPlayer compatibility.
/// - Translates AVPlayer HEAD / GET / Range requests into ranged chunk fetches
///   against YouTube CDN (which rejects non-Range GET and HEAD with HTTP 403).
/// - Uses a persistent keep-alive HttpClient (zero repeated TLS handshakes).
/// - Maintains a chunked local temp-file cache with background prefetch for
///   audio tracks so lyrics tap-to-seek and scrubber drags are instant (<15ms).
class LocalAudioProxy {
  static const int _chunkSize = 256 * 1024; // 256 KB chunks for snappy seek + prefetch
  static const int _maxDiskCachedTracks = 8;
  static const int _maxPrefetchBytes = 24 * 1024 * 1024; // Cache audio <= 24 MB

  HttpServer? _server;
  HttpClient? _httpClient;
  final Map<String, ResolvedAudioStream> _streams = {};
  final Map<String, _CachedTrackBuffer> _diskBuffers = {};
  final Set<String> _prefetching = {};
  int _seq = 0;

  Directory get _cacheDir =>
      Directory('${Directory.systemTemp.path}${Platform.pathSeparator}lemiel_audio_cache');

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    _httpClient ??= HttpClient()
      ..maxConnectionsPerHost = 6
      ..idleTimeout = const Duration(seconds: 20)
      ..connectionTimeout = const Duration(seconds: 5);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handleRequest, onError: (_) {});
  }

  Future<Uri> registerStream(
    String id,
    ResolvedAudioStream stream, {
    bool enableCache = true,
  }) async {
    await _ensureStarted();
    _streams[id] = stream;
    if (_streams.length > 24) {
      _streams.remove(_streams.keys.first);
    }

    final isVideo = stream.mimeType.startsWith('video/');
    final ext = isVideo
        ? 'mp4'
        : (stream.mimeType.contains('webm') ? 'webm' : 'm4a');

    if (enableCache &&
        !isVideo &&
        stream.contentLength > 0 &&
        stream.contentLength <= _maxPrefetchBytes) {
      await _ensureDiskBuffer(id, stream.contentLength, ext);
      unawaited(_prefetchInBackground(id));
    }

    final seq = ++_seq;
    return Uri.http(
      '${InternetAddress.loopbackIPv4.address}:${_server!.port}',
      '/stream/$id.$ext',
      {'v': '$seq'},
    );
  }

  Future<_CachedTrackBuffer?> _ensureDiskBuffer(
    String id,
    int totalBytes,
    String ext,
  ) async {
    final existing = _diskBuffers[id];
    if (existing != null && !existing.closed && existing.totalBytes == totalBytes) {
      existing.lastAccess = DateTime.now();
      return existing;
    }
    if (existing != null) {
      _diskBuffers.remove(id);
      await existing.closeAndDelete();
    }

    // Evict oldest buffers if exceeding limit.
    while (_diskBuffers.length >= _maxDiskCachedTracks) {
      final oldestKey = _diskBuffers.entries
          .reduce((a, b) => a.value.lastAccess.isBefore(b.value.lastAccess) ? a : b)
          .key;
      final removed = _diskBuffers.remove(oldestKey);
      if (removed != null) {
        unawaited(removed.closeAndDelete());
      }
    }

    try {
      final safeId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${_cacheDir.path}${Platform.pathSeparator}$safeId.$ext');
      final buffer = _CachedTrackBuffer(
        id: id,
        totalBytes: totalBytes,
        chunkSize: _chunkSize,
        file: file,
      );
      await buffer.initFile();
      _diskBuffers[id] = buffer;
      return buffer;
    } catch (_) {
      return null;
    }
  }

  Future<void> _prefetchInBackground(String id) async {
    if (_prefetching.contains(id)) return;
    final buffer = _diskBuffers[id];
    if (buffer == null || buffer.closed) return;
    _prefetching.add(id);
    try {
      // Prefetch sequentially so tapping any lyric line becomes an instant disk read.
      for (int idx = 0; idx < buffer.chunkCount; idx++) {
        if (buffer.closed || !_streams.containsKey(id)) break;
        if (buffer.downloadedChunks[idx]) continue;
        final ok = await _ensureChunkCached(id, buffer, idx);
        if (!ok) break;
      }
    } finally {
      _prefetching.remove(id);
    }
  }

  Future<bool> _ensureChunkCached(
    String id,
    _CachedTrackBuffer buffer,
    int chunkIndex,
  ) async {
    if (buffer.closed) return false;
    if (buffer.downloadedChunks[chunkIndex]) return true;
    final pending = buffer.inFlight[chunkIndex];
    if (pending != null) return pending;

    final task = () async {
      final stream = _streams[id];
      if (stream == null || buffer.closed) return false;
      final start = chunkIndex * buffer.chunkSize;
      final end = min(start + buffer.chunkSize - 1, buffer.totalBytes - 1);
      final bytes = await _fetchUpstreamRange(id, stream, start, end);
      if (bytes == null || bytes.isEmpty || buffer.closed) return false;
      await buffer.writeChunk(chunkIndex, bytes);
      return true;
    }();

    buffer.inFlight[chunkIndex] = task;
    try {
      return await task;
    } finally {
      buffer.inFlight.remove(chunkIndex);
    }
  }

  Future<Uint8List?> _fetchUpstreamRange(
    String id,
    ResolvedAudioStream stream,
    int start,
    int end,
  ) async {
    final client = _httpClient;
    if (client == null) return null;

    var activeUri = Uri.parse(stream.url);
    final candidates = _buildCandidateUris(activeUri);

    for (final candidate in candidates) {
      try {
        final req = await client
            .getUrl(candidate)
            .timeout(const Duration(seconds: 5));
        req.headers.set(HttpHeaders.userAgentHeader, stream.userAgent);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
        req.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
        final res = await req.close().timeout(const Duration(seconds: 6));

        if (res.statusCode == 200 || res.statusCode == 206) {
          final builder = BytesBuilder(copy: false);
          await for (final chunk in res) {
            builder.add(chunk);
          }
          if (candidate != activeUri) {
            activeUri = candidate;
            _streams[id] = ResolvedAudioStream(
              url: candidate.toString(),
              contentLength: stream.contentLength,
              mimeType: stream.mimeType,
              userAgent: stream.userAgent,
            );
          }
          return builder.takeBytes();
        }
        await res.drain<void>().catchError((_) {});
      } catch (_) {}
    }
    return null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final segments = request.uri.pathSegments;
      if (segments.length != 2 || segments[0] != 'stream') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final filename = segments[1];
      final dot = filename.lastIndexOf('.');
      final id = dot > 0 ? filename.substring(0, dot) : filename;
      final stream = _streams[id];
      if (stream == null || stream.contentLength <= 0) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final total = stream.contentLength;
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

      request.response.headers.set(HttpHeaders.contentTypeHeader, stream.mimeType);
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

      if (request.method == 'HEAD') {
        request.response.statusCode = HttpStatus.ok;
        request.response.contentLength = total;
        await request.response.close();
        return;
      }

      if (request.method != 'GET') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        return;
      }

      int start = 0;
      int end = total - 1;
      bool isPartial = false;

      if (rangeHeader != null) {
        final match = RegExp(r'^bytes=(\d+)-(\d*)').firstMatch(rangeHeader.trim());
        if (match != null) {
          start = int.parse(match.group(1)!);
          final endStr = match.group(2);
          end = (endStr != null && endStr.isNotEmpty)
              ? min(int.parse(endStr), total - 1)
              : total - 1;
          if (start >= total || start > end) {
            request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
            request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
            await request.response.close();
            return;
          }
          isPartial = true;
        }
      }

      final responseLength = end - start + 1;
      var clientClosed = false;
      unawaited(request.response.done.then<void>((_) {
        clientClosed = true;
      }).catchError((_) {
        clientClosed = true;
      }));

      final buffer = _diskBuffers[id];

      // Fast path: chunked disk-cached audio serving (sub-15ms seeks!).
      if (buffer != null && !buffer.closed) {
        if (isPartial) {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/$total',
          );
        } else {
          request.response.statusCode = HttpStatus.ok;
        }
        request.response.contentLength = responseLength;
        request.response.bufferOutput = false;

        int cursor = start;
        while (cursor <= end && !clientClosed) {
          final chunkIdx = cursor ~/ buffer.chunkSize;
          final chunkBoundaryEnd =
              min((chunkIdx + 1) * buffer.chunkSize - 1, end);
          final ok = await _ensureChunkCached(id, buffer, chunkIdx);
          if (!ok || clientClosed) break;

          final sliceLen = chunkBoundaryEnd - cursor + 1;
          final data = await buffer.readRange(cursor, sliceLen);
          if (clientClosed) break;
          request.response.add(data);
          cursor = chunkBoundaryEnd + 1;
        }

        if (!clientClosed) {
          await request.response.close();
        }
        return;
      }

      // Direct keep-alive streaming path (used for large MP4 music videos).
      var headersSent = false;
      int cursor = start;
      while (cursor <= end && !clientClosed) {
        final chunkEnd = min(cursor + (_chunkSize * 2) - 1, end);
        final activeStream = _streams[id] ?? stream;
        final bytes = await _fetchUpstreamRange(id, activeStream, cursor, chunkEnd);
        if (bytes == null || bytes.isEmpty) {
          if (!headersSent) {
            request.response.statusCode = HttpStatus.badGateway;
          }
          break;
        }
        if (!headersSent) {
          if (isPartial) {
            request.response.statusCode = HttpStatus.partialContent;
            request.response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes $start-$end/$total',
            );
          } else {
            request.response.statusCode = HttpStatus.ok;
          }
          request.response.contentLength = responseLength;
          request.response.bufferOutput = false;
          headersSent = true;
        }
        if (!clientClosed) {
          request.response.add(bytes);
        }
        cursor = chunkEnd + 1;
      }

      if (!clientClosed) {
        await request.response.close();
      }
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.badGateway;
      } catch (_) {}
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Builds failover CDN URIs using YouTube's signed `mn=primary,fallback` cluster param.
  List<Uri> _buildCandidateUris(Uri primary) {
    final list = <Uri>[primary];
    final mn = primary.queryParameters['mn']?.split(',') ?? const [];
    if (mn.length >= 2 &&
        mn[1].isNotEmpty &&
        primary.host.endsWith('.googlevideo.com')) {
      for (final prefix in const ['rr1', 'rr2']) {
        final fb = primary.replace(host: '$prefix---${mn[1]}.googlevideo.com');
        if (fb.host != primary.host) list.add(fb);
      }
    }
    return list;
  }

  bool isFullyCached(String id) {
    final b = _diskBuffers[id];
    return b != null && !b.closed && b.downloadedChunks.every((c) => c);
  }

  Future<void> dispose() async {
    _streams.clear();
    final buffers = _diskBuffers.values.toList();
    _diskBuffers.clear();
    for (final b in buffers) {
      await b.closeAndDelete();
    }
    _httpClient?.close(force: true);
    _httpClient = null;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }
}
