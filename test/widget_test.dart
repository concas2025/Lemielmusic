import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lemielmusic/models/track.dart';
import 'package:lemielmusic/services/local_audio_proxy.dart';
import 'package:lemielmusic/services/lyrics_service.dart';
import 'package:lemielmusic/widgets/glass.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('Track model artwork upscaling and formatting', () {
    const track = Track(
      id: 'abc123',
      title: 'Test Song',
      artist: 'Lemiel',
      thumbnailUrl: 'https://lh3.googleusercontent.com/sample=w120-h120-l90-rj',
      durationSeconds: 185,
    );

    expect(
      track.artworkUrl,
      'https://lh3.googleusercontent.com/sample=w600-h600-l90-rj',
    );
    expect(track.formattedDuration, '3:05');

    final restored = Track.fromJson(track.toJson());
    expect(restored, track);
    expect(restored.title, 'Test Song');
  });

  test('LRC synced lyrics parser parses timestamps correctly', () {
    const sampleLrc = '''
[00:12.34] First line
[01:05.50] Second line
[bad] Ignored line
''';
    final lines = LyricsService.parseLrc(sampleLrc);
    expect(lines.length, 2);
    expect(lines[0].time, const Duration(seconds: 12, milliseconds: 340));
    expect(lines[0].text, 'First line');
    expect(lines[1].time, const Duration(minutes: 1, seconds: 5, milliseconds: 500));
  });

  test('LocalAudioProxy translates HEAD, Range, and non-Range GET for strict CDN', () async {
    HttpOverrides.global = null;

    // Simulate YouTube CDN: rejects HEAD and non-Range GET with 403, serves 206 on Range GET.
    final payload = Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));
    final fakeCdn = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    fakeCdn.listen((req) async {
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (req.method != 'GET' || range == null) {
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
        return;
      }
      final m = RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(range)!;
      final start = int.parse(m.group(1)!);
      final end = int.parse(m.group(2)!);
      final slice = payload.sublist(start, end + 1);
      req.response.statusCode = HttpStatus.partialContent;
      req.response.headers.set(HttpHeaders.contentTypeHeader, 'audio/mp4');
      req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/${payload.length}');
      req.response.contentLength = slice.length;
      req.response.add(slice);
      await req.response.close();
    });

    final proxy = LocalAudioProxy();
    try {
      final cdnUrl = 'http://127.0.0.1:${fakeCdn.port}/videoplayback';
      final proxyUri = await proxy.registerStream(
        'testId',
        ResolvedAudioStream(
          url: cdnUrl,
          contentLength: payload.length,
          mimeType: 'audio/mp4',
          userAgent: 'TestAgent',
        ),
      );
      expect(proxyUri.path, endsWith('.m4a'));

      // 1. AVPlayer HEAD probe
      final headRes = await http.head(proxyUri);
      expect(headRes.statusCode, 200);
      expect(headRes.headers['content-type'], 'audio/mp4');
      expect(headRes.headers['accept-ranges'], 'bytes');
      expect(headRes.headers['content-length'], '${payload.length}');

      // 2. AVPlayer 2-byte Range probe (0-1)
      final r01 = await http.get(proxyUri, headers: {'Range': 'bytes=0-1'});
      expect(r01.statusCode, 206);
      expect(r01.headers['content-range'], 'bytes 0-1/${payload.length}');
      expect(r01.bodyBytes, payload.sublist(0, 2));

      // 3. Mid-song seek Range
      final rSeek = await http.get(proxyUri, headers: {'Range': 'bytes=1000-1511'});
      expect(rSeek.statusCode, 206);
      expect(rSeek.bodyBytes, payload.sublist(1000, 1512));

      // 4. Full GET without Range header (would be 403 directly on YouTube CDN)
      final rFull = await http.get(proxyUri);
      expect(rFull.statusCode, 200);
      expect(rFull.bodyBytes, payload);
    } finally {
      await proxy.dispose();
      await fakeCdn.close(force: true);
    }
  });

  testWidgets('GlassSurface renders child widget cleanly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassSurface(
            child: Text('Lemielmusic'),
          ),
        ),
      ),
    );
    expect(find.text('Lemielmusic'), findsOneWidget);
  });
}
