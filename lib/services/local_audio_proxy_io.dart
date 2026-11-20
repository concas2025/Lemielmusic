import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
        _raf ??= await file.open(mode: FileMode.write);
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
///   against YouTube CDN.
/// - Validates exact byte length per chunk (prevents truncated zeroed audio frames).
/// - Uses a persistent keep-alive HttpClient + chunked temp-file cache with
///   background prefetch for instant (<15ms) lyrics tap-to-seek.
/// - Supports automatic stream URL refresh via [onRefreshStream] if a CDN URL
///   expires (HTTP 403/410) mid-playback.
class LocalAudioProxy {
  static const int _chunkSize = 256 * 1024; // 256 KB chunks
  static const int _maxDiskCachedTracks = 8;
  static const int _maxPrefetchBytes = 40 * 1024 * 1024; // Cache tracks <= 40 MB

  final Future<ResolvedAudioStream?> Function(String id)? onRefreshStream;

  HttpServer? _server;
  HttpClient? _httpClient;
  final Map<String, ResolvedAudioStream> _streams = {};
  final Map<String, _CachedTrackBuffer> _diskBuffers = {};
  final Set<String> _prefetching = {};
  final Map<String, Future<ResolvedAudioStream?>> _refreshing = {};
  int _seq = 0;

  LocalAudioProxy({this.onRefreshStream});

  Directory get _cacheDir =>
      Directory('${Directory.systemTemp.path}${Platform.pathSeparator}lemiel_audio_cache');

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    _httpClient ??= HttpClient()
      ..maxConnectionsPerHost = 6
      ..idleTimeout = const Duration(seconds: 25)
      ..connectionTimeout = const Duration(seconds: 6);
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
        stream.contentLength > 0 &&
        stream.contentLength <= _maxPrefetchBytes) {
      await _ensureDiskBuffer(id, stream.contentLength, ext);
      if (!isVideo) {
        unawaited(_prefetchInBackground(id));
      }
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
    } catch (e) {
      debugPrint('[LemielAudio] Disk cache init failed for $id: $e');
      return null;
    }
  }

  Future<void> _prefetchInBackground(String id) async {
    if (_prefetching.contains(id)) return;
    final buffer = _diskBuffers[id];
    if (buffer == null || buffer.closed) return;
    _prefetching.add(id);
    int consecutiveFailures = 0;
    try {
      for (int idx = 0; idx < buffer.chunkCount; idx++) {
        if (buffer.closed || !_streams.containsKey(id)) break;
        if (buffer.downloadedChunks[idx]) continue;
        final ok = await _ensureChunkCached(id, buffer, idx);
        if (ok) {
          consecutiveFailures = 0;
        } else {
          consecutiveFailures++;
          debugPrint(
            '[LemielAudio] Prefetch chunk $idx/${buffer.chunkCount} failed for $id (failures=$consecutiveFailures)',
          );
          if (consecutiveFailures >= 3) break;
          await Future<void>.delayed(Duration(milliseconds: 350 * consecutiveFailures));
        }
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
      final start = chunkIndex * buffer.chunkSize;
      final end = min(start + buffer.chunkSize - 1, buffer.totalBytes - 1);
      final expectedLen = end - start + 1;

      for (int attempt = 0; attempt < 2; attempt++) {
        final stream = _streams[id];
        if (stream == null || buffer.closed) return false;

        final result = await _fetchUpstreamRange(id, stream, start, end);
        if (result.bytes != null &&
            result.bytes!.length == expectedLen &&
            !buffer.closed) {
          final bytes = result.bytes!;
          if (chunkIndex == 0 && stream.mimeType.startsWith('audio/mp4')) {
            if (normalizeFragmentedMp4Header(bytes)) {
              debugPrint('[LemielAudio] Normalized fMP4 moov duration for $id');
            }
          }
          await buffer.writeChunk(chunkIndex, bytes);
          return true;
        }

        // If upstream rejected with 403/410 (e.g. expired URL), try refreshing once.
        if (attempt == 0 &&
            (result.statusCode == 403 || result.statusCode == 410) &&
            onRefreshStream != null) {
          final refreshed = await _tryRefreshStream(id, expectedTotal: buffer.totalBytes);
          if (refreshed != null) continue;
        }
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
      }
      return false;
    }();

    buffer.inFlight[chunkIndex] = task;
    try {
      return await task;
    } finally {
      buffer.inFlight.remove(chunkIndex);
    }
  }

  Future<ResolvedAudioStream?> _tryRefreshStream(
    String id, {
    required int expectedTotal,
  }) async {
    final existing = _refreshing[id];
    if (existing != null) return existing;

    final task = () async {
      try {
        debugPrint('[LemielAudio] Refreshing upstream URL for $id after 403/410');
        final fresh = await onRefreshStream?.call(id);
        if (fresh != null && fresh.contentLength == expectedTotal) {
          _streams[id] = fresh;
          return fresh;
        }
        if (fresh != null) {
          debugPrint(
            '[LemielAudio] Refreshed URL contentLength mismatch for $id (${fresh.contentLength} != $expectedTotal)',
          );
        }
      } catch (e) {
        debugPrint('[LemielAudio] Refresh stream failed for $id: $e');
      }
      return null;
    }();

    _refreshing[id] = task;
    try {
      return await task;
    } finally {
      _refreshing.remove(id);
    }
  }

  Future<({Uint8List? bytes, int? statusCode})> _fetchUpstreamRange(
    String id,
    ResolvedAudioStream stream,
    int start,
    int end,
  ) async {
    final client = _httpClient;
    if (client == null) return (bytes: null, statusCode: null);

    final expectedLen = end - start + 1;
    var activeUri = Uri.parse(stream.url);
    final candidates = _buildCandidateUris(activeUri);
    int? lastStatus;

    for (final candidate in candidates) {
      try {
        final req = await client
            .getUrl(candidate)
            .timeout(const Duration(seconds: 6));
        req.headers.set(HttpHeaders.userAgentHeader, stream.userAgent);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
        req.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
        final res = await req.close().timeout(const Duration(seconds: 8));
        lastStatus = res.statusCode;

        if (res.statusCode == 200 || res.statusCode == 206) {
          final builder = BytesBuilder(copy: false);
          await for (final chunk in res.timeout(const Duration(seconds: 10))) {
            builder.add(chunk);
          }
          final bytes = builder.takeBytes();
          if (bytes.length != expectedLen) {
            debugPrint(
              '[LemielAudio] Truncated chunk for $id bytes=$start-$end (got ${bytes.length}/$expectedLen)',
            );
            continue;
          }
          if (candidate != activeUri) {
            activeUri = candidate;
            _streams[id] = ResolvedAudioStream(
              url: candidate.toString(),
              contentLength: stream.contentLength,
              mimeType: stream.mimeType,
              userAgent: stream.userAgent,
              duration: stream.duration,
            );
          }
          return (bytes: bytes, statusCode: res.statusCode);
        }
        debugPrint(
          '[LemielAudio] Upstream HTTP ${res.statusCode} for $id range=$start-$end host=${candidate.host}',
        );
        await res.drain<void>().catchError((_) {});
      } catch (e) {
        debugPrint(
          '[LemielAudio] Upstream error for $id range=$start-$end: $e',
        );
      }
    }
    return (bytes: null, statusCode: lastStatus);
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

      // Fast path: chunked disk-cached serving (sub-15ms seeks).
      if (buffer != null && !buffer.closed) {
        // Ensure the first chunk is fetched BEFORE sending 200/206 headers so
        // an immediate upstream failure returns a clean 502 instead of a broken body.
        final firstChunkIdx = start ~/ buffer.chunkSize;
        final firstOk = await _ensureChunkCached(id, buffer, firstChunkIdx);
        if (!firstOk) {
          request.response.statusCode = HttpStatus.badGateway;
          await request.response.close();
          return;
        }

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
        int chunksSent = 0;
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
          chunksSent++;
          // Flush every 2 chunks so AVPlayer backpressure keeps memory usage flat.
          if (chunksSent % 2 == 0) {
            await request.response.flush();
          }
          cursor = chunkBoundaryEnd + 1;
        }

        if (!clientClosed) {
          if (cursor <= end) {
            // Abort socket cleanly rather than closing with mismatched Content-Length.
            final socket = await request.response.detachSocket(writeHeaders: false);
            socket.destroy();
          } else {
            await request.response.close();
          }
        }
        return;
      }

      // Direct keep-alive streaming path (used for large MP4 music videos).
      var headersSent = false;
      int cursor = start;
      while (cursor <= end && !clientClosed) {
        final chunkEnd = min(cursor + (_chunkSize * 2) - 1, end);
        final activeStream = _streams[id] ?? stream;
        final result =
            await _fetchUpstreamRange(id, activeStream, cursor, chunkEnd);
        final bytes = result.bytes;
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
          if (cursor == 0 && activeStream.mimeType.startsWith('audio/mp4')) {
            normalizeFragmentedMp4Header(bytes);
          }
          request.response.add(bytes);
          await request.response.flush();
        }
        cursor = chunkEnd + 1;
      }

      if (!clientClosed) {
        if (headersSent && cursor <= end) {
          final socket = await request.response.detachSocket(writeHeaders: false);
          socket.destroy();
        } else {
          await request.response.close();
        }
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

  /// YouTube DASH fMP4 (`itag=140`) writes the full track duration into `moov`
  /// (`mvhd`/`tkhd`/`mdhd`) AND includes `mvex` + `moof` fragments for the same
  /// duration, causing iOS AVPlayer to sum both and report 2x duration.
  /// Per ISO/IEC 14496-12, zeroing those 3 header duration fields in-place when
  /// `mvex` is present fixes AVPlayer + Lock Screen duration with zero byte shift.
  static bool normalizeFragmentedMp4Header(Uint8List bytes) {
    final len = bytes.length;
    if (len < 32) return false;
    final data = ByteData.sublistView(bytes);

    int pos = 0;
    while (pos + 8 <= len) {
      final box = _readBox(data, pos, len);
      if (box == null) break;
      if (box.type == 0x6D6F6F76 /* 'moov' */) {
        if (!_containsChildBox(data, box.contentStart, box.end, 0x6D766578 /* 'mvex' */)) {
          return false;
        }
        return _zeroMoovDurations(bytes, data, box.contentStart, box.end);
      }
      pos = box.end;
    }
    return false;
  }

  static ({int type, int contentStart, int end})? _readBox(
    ByteData data,
    int pos,
    int limit,
  ) {
    if (pos + 8 > limit) return null;
    int size = data.getUint32(pos);
    final type = data.getUint32(pos + 4);
    int headerLen = 8;
    if (size == 1) {
      if (pos + 16 > limit) return null;
      size = data.getUint64(pos + 8);
      headerLen = 16;
    } else if (size == 0) {
      size = limit - pos;
    }
    if (size < headerLen || pos + size > limit) return null;
    return (type: type, contentStart: pos + headerLen, end: pos + size);
  }

  static bool _containsChildBox(
    ByteData data,
    int start,
    int end,
    int targetType,
  ) {
    int pos = start;
    while (pos + 8 <= end) {
      final box = _readBox(data, pos, end);
      if (box == null) break;
      if (box.type == targetType) return true;
      pos = box.end;
    }
    return false;
  }

  static bool _zeroMoovDurations(
    Uint8List bytes,
    ByteData data,
    int start,
    int end,
  ) {
    bool patched = false;
    int pos = start;
    while (pos + 8 <= end) {
      final box = _readBox(data, pos, end);
      if (box == null) break;
      final t = box.type;
      if (t == 0x7472616B /* 'trak' */ || t == 0x6D646961 /* 'mdia' */) {
        if (_zeroMoovDurations(bytes, data, box.contentStart, box.end)) {
          patched = true;
        }
      } else if (t == 0x6D766864 /* 'mvhd' */ || t == 0x6D646864 /* 'mdhd' */) {
        if (box.contentStart >= box.end) {
          pos = box.end;
          continue;
        }
        final ver = bytes[box.contentStart];
        final durOff = box.contentStart + (ver == 1 ? 24 : 16);
        final durLen = ver == 1 ? 8 : 4;
        if (durOff + durLen <= box.end) {
          for (int i = 0; i < durLen; i++) {
            bytes[durOff + i] = 0;
          }
          patched = true;
        }
      } else if (t == 0x746B6864 /* 'tkhd' */) {
        if (box.contentStart >= box.end) {
          pos = box.end;
          continue;
        }
        final ver = bytes[box.contentStart];
        final durOff = box.contentStart + (ver == 1 ? 28 : 20);
        final durLen = ver == 1 ? 8 : 4;
        if (durOff + durLen <= box.end) {
          for (int i = 0; i < durLen; i++) {
            bytes[durOff + i] = 0;
          }
          patched = true;
        }
      }
      pos = box.end;
    }
    return patched;
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
