import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// Local loopback HTTP server for iOS AVPlayer compatibility.
/// Translates AVPlayer HEAD / GET / Range requests into ranged chunk fetches
/// against YouTube CDN (which rejects non-Range GET and HEAD with HTTP 403).
class LocalAudioProxy {
  static const int _chunkSize = 512 * 1024; // 512 KB per upstream Range fetch

  HttpServer? _server;
  final Map<String, ResolvedAudioStream> _streams = {};
  int _seq = 0;

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handleRequest, onError: (_) {});
  }

  Future<Uri> registerStream(String id, ResolvedAudioStream stream) async {
    await _ensureStarted();
    _streams[id] = stream;
    if (_streams.length > 20) {
      _streams.remove(_streams.keys.first);
    }
    final ext = stream.mimeType.contains('webm') ? 'webm' : 'm4a';
    final seq = ++_seq;
    return Uri.http(
      '${InternetAddress.loopbackIPv4.address}:${_server!.port}',
      '/stream/$id.$ext',
      {'v': '$seq'},
    );
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
      var headersSent = false;
      var clientClosed = false;
      unawaited(request.response.done.then<void>((_) {
        clientClosed = true;
      }).catchError((_) {
        clientClosed = true;
      }));

      var activeUri = Uri.parse(stream.url);
      final candidates = _buildCandidateUris(activeUri);
      int cursor = start;

      while (cursor <= end && !clientClosed) {
        final chunkEnd = min(cursor + _chunkSize - 1, end);
        http.StreamedResponse? upstreamRes;
        http.Client? chunkClient;

        for (final candidate in candidates) {
          if (clientClosed) break;
          chunkClient = http.Client();
          try {
            final req = http.Request('GET', candidate)
              ..headers['User-Agent'] = stream.userAgent
              ..headers['Range'] = 'bytes=$cursor-$chunkEnd';
            final res = await chunkClient
                .send(req)
                .timeout(const Duration(seconds: 5));
            if (res.statusCode == 200 || res.statusCode == 206) {
              upstreamRes = res;
              if (candidate != activeUri) {
                activeUri = candidate;
                _streams[id] = ResolvedAudioStream(
                  url: candidate.toString(),
                  contentLength: stream.contentLength,
                  mimeType: stream.mimeType,
                  userAgent: stream.userAgent,
                );
              }
              break;
            }
            await res.stream.drain<void>().catchError((_) {});
            chunkClient.close();
          } catch (_) {
            chunkClient.close();
          }
        }

        if (upstreamRes == null) {
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

        try {
          await for (final data in upstreamRes.stream) {
            if (clientClosed) break;
            request.response.add(data);
          }
        } finally {
          chunkClient?.close();
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
    if (mn.length >= 2 && mn[1].isNotEmpty && primary.host.endsWith('.googlevideo.com')) {
      for (final prefix in const ['rr1', 'rr2']) {
        final fb = primary.replace(host: '$prefix---${mn[1]}.googlevideo.com');
        if (fb.host != primary.host) list.add(fb);
      }
    }
    return list;
  }

  Future<void> dispose() async {
    _streams.clear();
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }
}
