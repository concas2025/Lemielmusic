import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:material_ui/material_ui.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'services/import_service.dart';
import 'services/lyrics_service.dart';
import 'services/player_controller.dart';
import 'services/settings_controller.dart';
import 'services/storage_service.dart';
import 'services/ytm_service.dart';
import 'theme/lemiel_theme.dart';
import 'widgets/glass.dart';
import 'widgets/liquid_dock.dart';
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
  final settingsController = SettingsController(storage: storage);
  await settingsController.init();

  final lyrics = LyricsService();
  final importService = ImportService(ytm: ytm);
  final controller = PlayerController(
    ytm: ytm,
    storage: storage,
    settingsController: settingsController,
  );
  await controller.init();

  runApp(LemielmusicApp(
    controller: controller,
    settingsController: settingsController,
    ytm: ytm,
    lyrics: lyrics,
    importService: importService,
  ));
}

class LemielmusicApp extends StatefulWidget {
  final PlayerController controller;
  final SettingsController settingsController;
  final YtmService ytm;
  final LyricsService lyrics;
  final ImportService importService;

  const LemielmusicApp({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.ytm,
    required this.lyrics,
    required this.importService,
  });

  @override
  State<LemielmusicApp> createState() => _LemielmusicAppState();
}

class _LemielmusicAppState extends State<LemielmusicApp> {
  @override
  void initState() {
    super.initState();
    widget.settingsController.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settingsController.settings;
    final lemielTheme = LemielTheme.fromSettings(settings);
    final showOnboarding = !widget.settingsController.profile.onboardingDone;

    return MaterialApp(
      title: 'Lemielmusic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: lemielTheme.canvas,
        colorScheme: ColorScheme.dark(
          primary: settings.accentColor,
          surface: lemielTheme.surface,
        ),
        useMaterial3: true,
        extensions: [lemielTheme],
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        child: showOnboarding
            ? OnboardingScreen(
                key: const ValueKey('onboarding'),
                settingsController: widget.settingsController,
                onComplete: () => setState(() {}),
              )
            : _MainShell(
                key: const ValueKey('main_shell'),
                controller: widget.controller,
                settingsController: widget.settingsController,
                ytm: widget.ytm,
                lyrics: widget.lyrics,
                importService: widget.importService,
              ),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  final PlayerController controller;
  final SettingsController settingsController;
  final YtmService ytm;
  final LyricsService lyrics;
  final ImportService importService;

  const _MainShell({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.ytm,
    required this.lyrics,
    required this.importService,
  });

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _tabIndex = 0; // 0 = Home, 1 = Library, 2 = Profile, 3 = Search Orb

  static const _dockItems = [
    LiquidDockItem(icon: Icons.explore_rounded, label: 'Khám phá'),
    LiquidDockItem(icon: Icons.library_music_rounded, label: 'Thư viện'),
    LiquidDockItem(icon: Icons.badge_rounded, label: 'Hồ sơ'),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.settingsController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.settingsController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Coordinated Mini Player -> Now Playing Hero + subtle scale/slide transition.
  void _openNowPlaying() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => NowPlayingScreen(
          controller: widget.controller,
          lyricsService: widget.lyrics,
          settingsController: widget.settingsController,
        ),
        transitionsBuilder: (_, animation, _, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
              ),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.14),
                end: Offset.zero,
              ).animate(curve),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = widget.controller.currentTrack;
    final settings = widget.settingsController.settings;
    final accent = settings.accentColor;

    return Scaffold(
      extendBody: true,
      body: AmbientBackground(
        artworkUrl: currentTrack?.artworkUrl,
        accentColor: accent,
        style: settings.backgroundStyle,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  HomeScreen(
                    controller: widget.controller,
                    settingsController: widget.settingsController,
                    ytm: widget.ytm,
                    importService: widget.importService,
                    onProfileTap: () => setState(() => _tabIndex = 2),
                  ),
                  LibraryScreen(
                    controller: widget.controller,
                    settingsController: widget.settingsController,
                    importService: widget.importService,
                  ),
                  ProfileScreen(
                    controller: widget.controller,
                    settingsController: widget.settingsController,
                  ),
                  SearchScreen(
                    controller: widget.controller,
                    settingsController: widget.settingsController,
                    ytm: widget.ytm,
                  ),
                ],
              ),
            ),

            // Floating Error Banner + Mini Player + Adaptive Dock
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GlassSurface(
                            borderRadius: 16,
                            blur: 20,
                            opacity: 0.28,
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
                          accentColor: accent,
                          highGlass: settings.highGlass,
                          onTap: _openNowPlaying,
                        ),
                        const SizedBox(height: 10),
                      ],
                      LiquidFloatingDock(
                        items: _dockItems,
                        activeIndex: _tabIndex,
                        accentColor: accent,
                        highGlass: settings.highGlass,
                        onSelect: (idx) => setState(() => _tabIndex = idx),
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
