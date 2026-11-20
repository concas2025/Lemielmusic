import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lemielmusic/models/app_settings.dart';
import 'package:lemielmusic/models/track.dart';
import 'package:lemielmusic/models/user_profile.dart';
import 'package:lemielmusic/screens/audio_lab_screen.dart';
import 'package:lemielmusic/screens/customisation_screen.dart';
import 'package:lemielmusic/screens/library_screen.dart';
import 'package:lemielmusic/screens/lyrics_share_screen.dart';
import 'package:lemielmusic/screens/onboarding_screen.dart';
import 'package:lemielmusic/screens/profile_screen.dart';
import 'package:lemielmusic/services/import_service.dart';
import 'package:lemielmusic/services/local_audio_proxy.dart';
import 'package:lemielmusic/services/lyrics_service.dart';
import 'package:lemielmusic/services/player_controller.dart';
import 'package:lemielmusic/services/settings_controller.dart';
import 'package:lemielmusic/services/storage_service.dart';
import 'package:lemielmusic/services/ytm_service.dart';
import 'package:lemielmusic/theme/lemiel_theme.dart';
import 'package:lemielmusic/widgets/glass.dart';
import 'package:lemielmusic/widgets/liquid_dock.dart';
import 'package:lemielmusic/widgets/profile_id_card.dart';
import 'package:lemielmusic/widgets/wavy_slider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('AppSettings persists Liquid Glass / Classic theme and all Audio Lab fields', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final ctrl = SettingsController(storage: storage);
    await ctrl.init();

    expect(ctrl.settings.visualTheme, AppVisualTheme.liquidGlass);
    expect(ctrl.settings.accentPreset, AccentPreset.monochrome);
    ctrl.setVisualTheme(AppVisualTheme.classic);
    expect(ctrl.settings.visualTheme, AppVisualTheme.classic);
    expect(ctrl.settings.isClassic, isTrue);

    const full = AppSettings(
      visualTheme: AppVisualTheme.classic,
      playerStyle: PlayerStyle.vinyl,
      backgroundStyle: PlayerBackgroundStyle.appleBlur,
      sliderStyle: SliderStyle.liquidPill,
      lyricsStyle: LyricsStyle.karaokePill,
      lyricsAlign: LyricsAlign.center,
      lyricsFontSize: 24.0,
      blurInactiveLyrics: false,
      audioQuality: AudioQualityTier.low,
      accentPreset: AccentPreset.indigo,
      glassQuality: GlassQuality.performance,
      lyricsProviderOrder: ['betterlyrics', 'lrclib', 'ytm', 'lyricsovh'],
      enabledLyricsProviders: ['betterlyrics', 'ytm'],
      playbackSpeed: 0.85,
      playbackPitch: 0.90,
      eqPreset: 'Bass Boost',
      eqBands: [6, 4, 0, -1, 1],
    );

    final restored = AppSettings.fromJson(full.toJson());
    expect(restored.visualTheme, AppVisualTheme.classic);
    expect(restored.playerStyle, PlayerStyle.vinyl);
    expect(restored.backgroundStyle, PlayerBackgroundStyle.appleBlur);
    expect(restored.sliderStyle, SliderStyle.liquidPill);
    expect(restored.lyricsStyle, LyricsStyle.karaokePill);
    expect(restored.lyricsAlign, LyricsAlign.center);
    expect(restored.lyricsFontSize, 24.0);
    expect(restored.blurInactiveLyrics, false);
    expect(restored.audioQuality, AudioQualityTier.low);
    expect(restored.accentPreset, AccentPreset.indigo);
    expect(restored.activeLyricsProviders, ['betterlyrics', 'ytm']);
    expect(restored.playbackSpeed, 0.85);
    expect(restored.playbackPitch, 0.90);
    expect(restored.eqPreset, 'Bass Boost');
  });

  test('UserProfile & LocalPlaylist serialize avatar presets, initials, and topArtists', () {
    const profile = UserProfile(
      displayName: 'Minh Anh',
      bio: 'Chill Vibes',
      avatarPresetIndex: 3,
      memberId: 'LM-2026-8888',
      joinedDate: '11/2026',
      silverCard: true,
      onboardingDone: true,
      totalPlays: 42,
      artistPlays: {'Sơn Tùng': 12, 'Đen Vâu': 25, 'Vũ.': 5},
    );

    final restored = UserProfile.fromJson(profile.toJson());
    expect(restored.initials, 'MA');
    expect(restored.avatarPresetIndex, 3);
    expect(restored.silverCard, true);
    expect(restored.topArtists.first.key, 'Đen Vâu');
    expect(restored.topArtists.first.value, 25);

    const playlist = LocalPlaylist(
      id: 'sp_1',
      name: 'My Spotify Mix',
      tracks: [
        Track(id: 'v1', title: 'Song A', artist: 'Artist A', thumbnailUrl: ''),
      ],
      createdAt: '2026-11-20T00:00:00Z',
      sourcePlatform: 'spotify',
    );
    final restoredPl = LocalPlaylist.fromJson(playlist.toJson());
    expect(restoredPl.platformLabel, 'Spotify');
    expect(restoredPl.tracks.length, 1);
  });

  test('LRC and Apple TTML parsers extract accurate synced timestamps', () {
    const sampleLrc = '''
[00:12.34] First line
[01:05.50] Second line
[bad] Ignored line
''';
    final lrcLines = LyricsService.parseLrc(sampleLrc);
    expect(lrcLines.length, 2);
    expect(lrcLines[0].time, const Duration(seconds: 12, milliseconds: 340));
    expect(lrcLines[1].time, const Duration(minutes: 1, seconds: 5, milliseconds: 500));

    const sampleTtml = '''
<tt><body><div>
  <p begin="14.250s" end="18.000s"><span>I&apos;ve been</span> trying to call</p>
  <p begin="01:02.500" end="01:06.000">Blinding &amp; Lights</p>
</div></body></tt>
''';
    final ttmlLines = LyricsService.parseTtml(sampleTtml);
    expect(ttmlLines.length, 2);
    expect(ttmlLines[0].time, const Duration(seconds: 14, milliseconds: 250));
    expect(ttmlLines[0].text, "I've been trying to call");
    expect(ttmlLines[1].time, const Duration(minutes: 1, seconds: 2, milliseconds: 500));
    expect(ttmlLines[1].text, 'Blinding & Lights');
  });

  test('ImportService detects platforms and extracts playlist IDs', () {
    expect(
      ImportService.detectPlatform('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=123'),
      'spotify',
    );
    expect(
      ImportService.extractSpotifyPlaylistId('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=123'),
      '37i9dQZF1DXcBWIGoYBM5M',
    );
    expect(
      ImportService.detectPlatform('https://music.apple.com/vn/playlist/top-100/pl.12345'),
      'apple_music',
    );
    expect(
      ImportService.detectPlatform('https://music.youtube.com/playlist?list=PLabc_123'),
      'youtube_music',
    );
    expect(
      ImportService.extractYouTubePlaylistId('https://music.youtube.com/playlist?list=PLabc_123'),
      'PLabc_123',
    );
    expect(ImportService.detectPlatform('https://example.com/nope'), isNull);
  });

  test('LocalAudioProxy caches past 1MB, validates chunk length, and auto-refreshes expired 403 URLs', () async {
    final prevOverrides = HttpOverrides.current;
    HttpOverrides.global = null;

    int upstreamRequests = 0;
    int refreshCalls = 0;
    // 1.3 MB payload (exceeds YouTube's 1.00 MiB cutoff)
    final payload = Uint8List.fromList(List<int>.generate(1350000, (i) => i % 251));
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

      // Simulate expired/403 URL on `/expired` past 1 MiB, while `/fresh` serves 100%
      if (req.uri.path == '/expired' && start >= 1048576) {
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
        return;
      }

      upstreamRequests++;
      final slice = payload.sublist(start, end + 1);
      req.response.statusCode = HttpStatus.partialContent;
      req.response.headers.set(HttpHeaders.contentTypeHeader, 'audio/mp4');
      req.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/${payload.length}',
      );
      req.response.contentLength = slice.length;
      req.response.add(slice);
      await req.response.close();
    });

    final freshUrl = 'http://127.0.0.1:${fakeCdn.port}/fresh';
    final expiredUrl = 'http://127.0.0.1:${fakeCdn.port}/expired';

    final proxy = LocalAudioProxy(
      onRefreshStream: (id) async {
        refreshCalls++;
        return ResolvedAudioStream(
          url: freshUrl,
          contentLength: payload.length,
          mimeType: 'audio/mp4',
          userAgent: 'TestAgent',
        );
      },
    );

    try {
      final proxyUri = await proxy.registerStream(
        'testOver1MB',
        ResolvedAudioStream(
          url: expiredUrl,
          contentLength: payload.length,
          mimeType: 'audio/mp4',
          userAgent: 'TestAgent',
        ),
      );
      expect(proxyUri.path, endsWith('.m4a'));

      // Full GET past 1.00 MiB triggers seamless onRefreshStream and delivers all 1.35 MB
      final rFull = await http.get(proxyUri);
      expect(rFull.statusCode, 200);
      expect(rFull.bodyBytes.length, payload.length);
      expect(rFull.bodyBytes, payload);
      expect(refreshCalls, greaterThanOrEqualTo(1));
      expect(proxy.isFullyCached('testOver1MB'), isTrue);

      // Subsequent seek past 1:30 hits disk cache with ZERO upstream requests
      final beforeSeek = upstreamRequests;
      final rSeek = await http.get(
        proxyUri,
        headers: {'Range': 'bytes=1100000-1200000'},
      );
      expect(rSeek.statusCode, 206);
      expect(rSeek.bodyBytes, payload.sublist(1100000, 1200001));
      expect(upstreamRequests, beforeSeek);
    } finally {
      await proxy.dispose();
      await fakeCdn.close(force: true);
      HttpOverrides.global = prevOverrides;
    }
  });

  testWidgets('Liquid Glass & Classic themes, Floating Dock, ID Card & Customisation work cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final settingsCtrl = SettingsController(storage: storage);
    await settingsCtrl.init();

    int selectedTab = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [LemielTheme.fromSettings(settingsCtrl.settings)],
        ),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SingleChildScrollView(
            child: Column(
              children: [
                const GlassSurface(isLens: true, child: Text('Liquid Lemiel')),
                ProfileIdCard(
                  profile: settingsCtrl.profile,
                  accentColor: settingsCtrl.settings.accentColor,
                  favoritesCount: 5,
                  onToggleFinish: settingsCtrl.toggleCardFinish,
                ),
                CustomMusicSlider(
                  value: 0.5,
                  bufferedValue: 0.8,
                  isPlaying: false,
                  style: SliderStyle.mochyWavy,
                  accentColor: const Color(0xFFFF375F),
                  onChanged: (_) {},
                  onChangeEnd: (_) {},
                ),
                LiquidFloatingDock(
                  items: const [
                    LiquidDockItem(icon: Icons.explore_rounded, label: 'Khám phá'),
                    LiquidDockItem(icon: Icons.library_music_rounded, label: 'Thư viện'),
                    LiquidDockItem(icon: Icons.badge_rounded, label: 'Hồ sơ'),
                  ],
                  activeIndex: selectedTab,
                  accentColor: const Color(0xFFFF375F),
                  highGlass: true,
                  onSelect: (idx) => selectedTab = idx,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Liquid Lemiel'), findsOneWidget);
    expect(find.text('ID CARD OF'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump();
    expect(selectedTab, 3);

    await tester.tap(find.text('Silver'));
    await tester.pump();
    expect(settingsCtrl.profile.silverCard, isTrue);

    // CustomisationScreen switches between Liquid Glass and Classic live
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [LemielTheme.fromSettings(settingsCtrl.settings)],
        ),
        home: CustomisationScreen(settingsController: settingsCtrl),
      ),
    );
    await tester.pump();
    expect(find.text('Chế độ giao diện (Theme)'), findsOneWidget);
    await tester.tap(find.text('Classic'));
    await tester.pump();
    expect(settingsCtrl.settings.visualTheme, AppVisualTheme.classic);
  });

  testWidgets('OnboardingScreen, LyricsShareScreen, AudioLabScreen, LibraryScreen, and ProfileScreen render cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final settingsCtrl = SettingsController(storage: storage);
    await settingsCtrl.init();

    bool completedOnboarding = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [LemielTheme.fromSettings(settingsCtrl.settings)],
        ),
        home: OnboardingScreen(
          settingsController: settingsCtrl,
          onComplete: () => completedOnboarding = true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Bắt đầu nghe nhạc'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu nghe nhạc'));
    await tester.pump();
    expect(completedOnboarding, isTrue);
    expect(settingsCtrl.profile.onboardingDone, isTrue);

    const sampleTrack = Track(
      id: 't1',
      title: 'Chúng Ta Của Hiện Tại',
      artist: 'Sơn Tùng M-TP',
      thumbnailUrl: '',
      durationSeconds: 301,
    );
    const sampleLyrics = [
      LyricLine(time: Duration(seconds: 10), text: 'Mùa thu mang giấc mơ quay về'),
      LyricLine(time: Duration(seconds: 15), text: 'Vẫn nguyên vẹn như hôm nào'),
      LyricLine(time: Duration(seconds: 20), text: 'Lá bay theo gió xôn xao'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: LyricsShareScreen(
          track: sampleTrack,
          lyrics: sampleLyrics,
          initialIndex: 0,
          profile: settingsCtrl.profile,
          accentColor: settingsCtrl.settings.accentColor,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Chia sẻ Lời bài hát'), findsOneWidget);

    final ytm = YtmService();
    final playerCtrl = PlayerController(
      ytm: ytm,
      storage: storage,
      settingsController: settingsCtrl,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AudioLabScreen(
          controller: playerCtrl,
          settingsController: settingsCtrl,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Audio\nLab'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: LibraryScreen(
            controller: playerCtrl,
            settingsController: settingsCtrl,
            importService: ImportService(ytm: ytm),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Nhập Playlist từ nền tảng khác'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [LemielTheme.fromSettings(settingsCtrl.settings)],
        ),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ProfileScreen(
            controller: playerCtrl,
            settingsController: settingsCtrl,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    ytm.dispose();
  });
}
