import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/search_screen.dart';
import 'services/lyrics_service.dart';
import 'services/player_controller.dart';
import 'services/storage_service.dart';
import 'services/ytm_service.dart';
import 'widgets/glass.dart';
import 'widgets/mini_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.lemiel.lemielmusic.audio',
        androidNotificationChannelName: 'Lemielmusic Playback',
        androidNotificationOngoing: true,
      );
    } catch (e) {
      debugPrint('JustAudioBackground init failed: $e');
    }
  }

  final ytm = YtmService();
  final storage = StorageService();
  final lyrics = LyricsService();
  final controller = PlayerController(ytm: ytm, storage: storage);
  await controller.init();

  runApp(LemielmusicApp(
    controller: controller,
    ytm: ytm,
    lyrics: lyrics,
  ));
}

class LemielmusicApp extends StatelessWidget {
  final PlayerController controller;
  final YtmService ytm;
  final LyricsService lyrics;

  const LemielmusicApp({
    super.key,
    required this.controller,
    required this.ytm,
    required this.lyrics,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lemielmusic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07070B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF375F),
          surface: Color(0xFF14141C),
        ),
        useMaterial3: true,
      ),
      home: _MainShell(
        controller: controller,
        ytm: ytm,
        lyrics: lyrics,
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  final PlayerController controller;
  final YtmService ytm;
  final LyricsService lyrics;

  const _MainShell({
    required this.controller,
    required this.ytm,
    required this.lyrics,
  });

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  void _openNowPlaying() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => NowPlayingScreen(
          controller: widget.controller,
          lyricsService: widget.lyrics,
        ),
        transitionsBuilder: (_, animation, _, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = widget.controller.currentTrack;

    return Scaffold(
      extendBody: true,
      body: AmbientBackground(
        artworkUrl: currentTrack?.artworkUrl,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  HomeScreen(
                    controller: widget.controller,
                    ytm: widget.ytm,
                    onSearchTap: () => setState(() => _tabIndex = 1),
                  ),
                  SearchScreen(
                    controller: widget.controller,
                    ytm: widget.ytm,
                  ),
                  LibraryScreen(controller: widget.controller),
                ],
              ),
            ),

            // Floating Mini Player + Frosted Glass Bottom Navigation Pill
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.controller.errorMessage != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: GlassSurface(
                            borderRadius: 16,
                            blur: 24,
                            opacity: 0.24,
                            tintColor: const Color(0xFFB00020),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFFF8A80),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.controller.errorMessage!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: widget.controller.clearError,
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (currentTrack != null) ...[
                        MiniPlayer(
                          controller: widget.controller,
                          onTap: _openNowPlaying,
                        ),
                        const SizedBox(height: 10),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: GlassSurface(
                          borderRadius: 28,
                          blur: 30,
                          opacity: 0.14,
                          tintColor: const Color(0xFF181822),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _NavButton(
                                icon: Icons.explore_rounded,
                                label: 'Khám phá',
                                active: _tabIndex == 0,
                                onTap: () => setState(() => _tabIndex = 0),
                              ),
                              _NavButton(
                                icon: Icons.search_rounded,
                                label: 'Tìm kiếm',
                                active: _tabIndex == 1,
                                onTap: () => setState(() => _tabIndex = 1),
                              ),
                              _NavButton(
                                icon: Icons.library_music_rounded,
                                label: 'Thư viện',
                                active: _tabIndex == 2,
                                onTap: () => setState(() => _tabIndex = 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF375F);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? accent : Colors.white.withValues(alpha: 0.58),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.58),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
