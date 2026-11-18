import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemielmusic/models/track.dart';
import 'package:lemielmusic/services/lyrics_service.dart';
import 'package:lemielmusic/widgets/glass.dart';

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
