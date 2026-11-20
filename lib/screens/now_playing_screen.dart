import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import '../models/app_settings.dart';
import '../models/track.dart';
import '../services/artwork_palette.dart';
import '../services/lyrics_service.dart';
import '../services/player_controller.dart';
import '../services/settings_controller.dart';
import '../widgets/glass.dart';
import '../widgets/wavy_slider.dart';
import 'audio_lab_screen.dart';
import 'lyrics_share_screen.dart';

/// Faithful Mochy-Music Flagship Player (`mochy_player.webp`) with:
/// - Full-bleed edge-to-edge artwork dissolving smoothly into the real
///   extracted dominant dark color of the song's cover art
/// - Outlined codec pill (`AAC`), clean monochrome circle actions, crisp white
///   seek bar with buffered track, bold white transport controls, and bottom
///   peek Lyrics/Queue dock
/// - Live customisation into Vinyl / Framed styles, Music Video mode, and
///   silky synchronized auto-scrolling Lyrics.
class NowPlayingScreen extends StatefulWidget {
  final PlayerController controller;
  final LyricsService lyricsService;
  final SettingsController settingsController;

  const NowPlayingScreen({
    super.key,
    required this.controller,
    required this.lyricsService,
    required this.settingsController,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  bool _showLyrics = false;
  bool _videoMode = false;
  bool _loadingVideo = false;
  String? _videoError;
  VideoPlayerController? _videoCtrl;
  String? _videoTrackId;

  String? _lyricsTrackId;
  bool _loadingLyrics = false;
  LyricsResult _lyricsResult = LyricsResult.empty;
  List<GlobalKey> _lyricKeys = const [];
  int _lastActiveLyricIndex = -1;
  bool _userScrollingLyrics = false;
  Timer? _resumeAutoScrollTimer;
  final ScrollController _lyricsScroll = ScrollController();

  ArtworkPalette _palette = ArtworkPalette.fallback;
  String? _paletteArtUrl;

  double? _dragSeekFraction;
  double _dismissDragOffset = 0.0;
  late final AnimationController _vinylCtrl;

  @override
  void initState() {
    super.initState();
    _vinylCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.controller.isPlaying) {
      _vinylCtrl.repeat();
    }
    widget.controller.addListener(_onPlayerUpdate);
    widget.settingsController.addListener(_onSettingsUpdate);
    _syncPalette();
    _maybeLoadLyrics();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPlayerUpdate);
    widget.settingsController.removeListener(_onSettingsUpdate);
    _resumeAutoScrollTimer?.cancel();
    _vinylCtrl.dispose();
    _lyricsScroll.dispose();
    _disposeVideo(resumeAudio: false);
    super.dispose();
  }

  void _onSettingsUpdate() {
    if (mounted) setState(() {});
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    final playing = widget.controller.isPlaying && !_videoMode;
    if (playing && !_vinylCtrl.isAnimating) {
      _vinylCtrl.repeat();
    } else if (!playing && _vinylCtrl.isAnimating) {
      _vinylCtrl.stop();
    }

    final track = widget.controller.currentTrack;
    if (_videoMode && track != null && _videoTrackId != track.id) {
      unawaited(_loadVideoForTrack(track));
    }

    _syncPalette();
    setState(() {});
    _maybeLoadLyrics();
  }

  void _syncPalette() {
    final url = widget.controller.currentTrack?.artworkUrl;
    if (url == null || url == _paletteArtUrl) return;
    _paletteArtUrl = url;
    final peeked = ArtworkPaletteService.peek(url);
    if (peeked != null) {
      _palette = peeked;
      return;
    }
    ArtworkPaletteService.extract(url).then((p) {
      if (mounted && _paletteArtUrl == url) {
        setState(() => _palette = p);
      }
    });
  }

  Future<void> _maybeLoadLyrics({String? forceProvider}) async {
    final track = widget.controller.currentTrack;
    if (!_showLyrics || track == null) return;
    if (forceProvider == null && _lyricsTrackId == track.id) return;

    _lyricsTrackId = track.id;
    _lastActiveLyricIndex = -1;
    _userScrollingLyrics = false;
    _resumeAutoScrollTimer?.cancel();
    setState(() {
      _loadingLyrics = true;
      _lyricsResult = LyricsResult.empty;
      _lyricKeys = const [];
    });

    final providers = widget.settingsController.settings.activeLyricsProviders;
    final result = await widget.lyricsService.fetchLyrics(
      track,
      providers: providers,
      forceProvider: forceProvider,
    );
    if (!mounted || _lyricsTrackId != track.id) return;
    setState(() {
      _lyricsResult = result;
      _lyricKeys = List<GlobalKey>.generate(
        result.lines.length,
        (_) => GlobalKey(),
      );
      _loadingLyrics = false;
    });
  }

  void _scrollToLyricIndex(int index, {bool force = false}) {
    if (index < 0 || index >= _lyricKeys.length) return;
    if (_userScrollingLyrics && !force) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _lyricKeys.length) return;
      final ctx = _lyricKeys[index].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.36,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onUserScrollLyrics() {
    if (!_userScrollingLyrics) {
      setState(() => _userScrollingLyrics = true);
    }
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _userScrollingLyrics = false);
      if (_lastActiveLyricIndex >= 0) {
        _scrollToLyricIndex(_lastActiveLyricIndex, force: true);
      }
    });
  }

  static int computeActiveLyricIndex(List<LyricLine> lines, Duration position) {
    int active = -1;
    Duration bestTime = Duration.zero;
    for (int i = 0; i < lines.length; i++) {
      final t = lines[i].time;
      if (t != null && position >= t) {
        if (active == -1 || t >= bestTime) {
          active = i;
          bestTime = t;
        }
      }
    }
    return active;
  }

  Future<void> _toggleVideoMode(bool enableVideo) async {
    if (_videoMode == enableVideo) return;
    final track = widget.controller.currentTrack;
    if (track == null) return;

    if (enableVideo) {
      setState(() {
        _videoMode = true;
        _showLyrics = false;
      });
      await _loadVideoForTrack(track);
    } else {
      await _disposeVideo(resumeAudio: true);
      if (mounted) setState(() => _videoMode = false);
    }
  }

  Future<void> _loadVideoForTrack(Track track) async {
    final startPos = widget.controller.currentPosition;
    await _disposeVideo(resumeAudio: false);
    if (!mounted) return;

    setState(() {
      _loadingVideo = true;
      _videoError = null;
      _videoTrackId = track.id;
    });

    try {
      await widget.controller.pauseForVideo();
      final localUri = await widget.controller.resolveLocalVideoUri(track.id);
      if (!mounted || !_videoMode || _videoTrackId != track.id) return;

      final ctrl = VideoPlayerController.networkUrl(localUri);
      await ctrl.initialize();
      if (!mounted || !_videoMode || _videoTrackId != track.id) {
        await ctrl.dispose();
        return;
      }
      if (startPos > Duration.zero && startPos < ctrl.value.duration) {
        await ctrl.seekTo(startPos);
      }
      await ctrl.play();
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {
        _videoCtrl = ctrl;
        _loadingVideo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingVideo = false;
        _videoError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _disposeVideo({required bool resumeAudio}) async {
    final ctrl = _videoCtrl;
    _videoCtrl = null;
    if (ctrl != null) {
      final pos = ctrl.value.isInitialized ? ctrl.value.position : Duration.zero;
      final wasPlaying = ctrl.value.isInitialized && ctrl.value.isPlaying;
      try {
        await ctrl.pause();
        await ctrl.dispose();
      } catch (_) {}
      if (resumeAudio) {
        await widget.controller.resumeFromVideo(pos, shouldPlay: wasPlaying);
      }
    }
  }

  String _fmt(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _closePlayer() {
    _disposeVideo(resumeAudio: _videoMode);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.controller.currentTrack;
    if (track == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final settings = widget.settingsController.settings;
    final accent = settings.accentColor;
    final isFav = widget.controller.isFavorite(track.id);
    final isFlagshipFullBleed =
        !_videoMode && !_showLyrics && settings.playerStyle == PlayerStyle.flagship;

    final dragFraction = (_dismissDragOffset / 320.0).clamp(0.0, 1.0);
    final dragScale = 1.0 - dragFraction * 0.06;
    final dragRadius = dragFraction * 28.0;

    final canvasColor = settings.backgroundStyle == PlayerBackgroundStyle.oledBlack
        ? Colors.black
        : _palette.darkSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onVerticalDragUpdate: _showLyrics
            ? null
            : (details) {
                if (details.delta.dy > 0 || _dismissDragOffset > 0) {
                  setState(() {
                    _dismissDragOffset =
                        (_dismissDragOffset + details.delta.dy).clamp(0.0, 340.0);
                  });
                }
              },
        onVerticalDragEnd: _showLyrics
            ? null
            : (details) {
                final vel = details.primaryVelocity ?? 0;
                if (vel > 420 || _dismissDragOffset > 130) {
                  _closePlayer();
                } else {
                  setState(() => _dismissDragOffset = 0.0);
                }
              },
        child: AnimatedContainer(
          duration: _dismissDragOffset == 0
              ? const Duration(milliseconds: 220)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _dismissDragOffset, 0)
            ..scaleByDouble(dragScale, dragScale, 1.0, 1.0),
          transformAlignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(dragRadius),
            ),
            child: AmbientBackground(
              artworkUrl: track.artworkUrl,
              accentColor: accent,
              dynamicTint: canvasColor,
              style: settings.backgroundStyle,
              enableArtworkBackdrop: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // MOCHY FLAGSHIP FULL-BLEED DISSOLVING ARTWORK BACKDROP
                  if (isFlagshipFullBleed)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: MediaQuery.of(context).size.height * 0.60,
                      child: Hero(
                        tag: 'now_playing_artwork_${track.id}',
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.50, 0.78, 1.0],
                            colors: [
                              Colors.white,
                              Colors.white,
                              Color(0x55FFFFFF),
                              Colors.transparent,
                            ],
                          ).createShader(bounds),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              track.artworkUrl.isEmpty
                                  ? Container(
                                      color: const Color(0xFF1C1C20),
                                      child: const Icon(
                                        Icons.music_note_rounded,
                                        size: 72,
                                        color: Colors.white24,
                                      ),
                                    )
                                  : Image.network(
                                      track.artworkUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: const Color(0xFF1C1C20),
                                      ),
                                    ),
                              // Soft top scrim for status bar & controls legibility
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.0, 0.24, 1.0],
                                    colors: [
                                      Colors.black.withValues(alpha: 0.44),
                                      Colors.transparent,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // Minimal Top Grabber & Header
                        const SizedBox(height: 6),
                        Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.34),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _closePlayer,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const Spacer(),
                              GlassSurface(
                                borderRadius: 20,
                                blur: 18,
                                isLens: true,
                                highQuality: settings.highGlass,
                                padding: const EdgeInsets.all(3),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ModeTab(
                                      label: 'Bài hát',
                                      active: !_videoMode,
                                      onTap: () => _toggleVideoMode(false),
                                    ),
                                    _ModeTab(
                                      label: 'Video',
                                      active: _videoMode,
                                      onTap: () => _toggleVideoMode(true),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Tuỳ chỉnh trực tiếp',
                                onPressed: () =>
                                    _openQuickCustomiseSheet(context),
                                icon: const Icon(
                                  Icons.tune_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Center Stage: Spacer for Full-Bleed Flagship OR Video / Lyrics / Vinyl / Framed
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              child: _videoMode
                                  ? _buildVideoView(accent)
                                  : _showLyrics
                                      ? _buildLyricsView(track, settings, accent)
                                      : isFlagshipFullBleed
                                          ? const SizedBox.expand(
                                              key: ValueKey('flagship_open'),
                                            )
                                          : _buildAltArtworkView(
                                              track,
                                              settings,
                                              accent,
                                            ),
                            ),
                          ),
                        ),

                        // MOCHY LOWER CONTROLS BLOCK (exact mochy_player.webp hierarchy)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                          child: Column(
                            children: [
                              // Title + AAC Codec Pill + Artist + Favorite & Lyrics Circle Buttons
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      layoutBuilder: (cur, prev) => Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [...prev, ?cur],
                                      ),
                                      child: Column(
                                        key: ValueKey(track.id),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  track.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.42),
                                                    width: 0.9,
                                                  ),
                                                ),
                                                child: Text(
                                                  settings.audioQuality ==
                                                          AudioQualityTier.low
                                                      ? 'AAC'
                                                      : 'AAC HQ',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.85),
                                                    fontSize: 9,
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            track.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.65),
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Mochy monochrome circular Favorite button
                                  SpringTap(
                                    onTap: () =>
                                        widget.controller.toggleFavorite(track),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            Colors.white.withValues(alpha: 0.12),
                                      ),
                                      child: Icon(
                                        isFav
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Mochy monochrome circular Lyrics toggle button
                                  SpringTap(
                                    onTap: () {
                                      if (_videoMode) _toggleVideoMode(false);
                                      setState(
                                          () => _showLyrics = !_showLyrics);
                                      _maybeLoadLyrics();
                                    },
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _showLyrics
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.12),
                                      ),
                                      child: Icon(
                                        _showLyrics
                                            ? Icons.keyboard_arrow_down_rounded
                                            : Icons.keyboard_arrow_up_rounded,
                                        color: _showLyrics
                                            ? Colors.black
                                            : Colors.white,
                                        size: 21,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (widget.controller.errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    widget.controller.errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFFF8A80),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 12),

                              // Clean Monochrome Progress & Buffer Bar
                              RepaintBoundary(
                                child: _buildProgressBar(settings, accent),
                              ),

                              const SizedBox(height: 16),

                              // Mochy Bold Pure-White Transport Controls (zero bulky circle!)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    onPressed: widget.controller.toggleShuffle,
                                    icon: Icon(
                                      Icons.shuffle_rounded,
                                      color: widget.controller.shuffle
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.42),
                                      size: 21,
                                    ),
                                  ),
                                  SpringTap(
                                    onTap: widget.controller.previous,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.fast_rewind_rounded,
                                        color: Colors.white,
                                        size: 42,
                                      ),
                                    ),
                                  ),
                                  SpringTap(
                                    pressedScale: 0.88,
                                    onTap: _onPlayPauseTap,
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Center(
                                        child: _isCenterBusy()
                                            ? const SizedBox(
                                                width: 30,
                                                height: 30,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.6,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 160,
                                                ),
                                                transitionBuilder: (c, a) =>
                                                    ScaleTransition(
                                                  scale: a,
                                                  child: c,
                                                ),
                                                child: Icon(
                                                  _isCenterPlaying()
                                                      ? Icons.pause_rounded
                                                      : Icons
                                                          .play_arrow_rounded,
                                                  key: ValueKey(
                                                      _isCenterPlaying()),
                                                  color: Colors.white,
                                                  size: 54,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  SpringTap(
                                    onTap: () => widget.controller.next(),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.fast_forward_rounded,
                                        color: Colors.white,
                                        size: 42,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed:
                                        widget.controller.cycleRepeatMode,
                                    icon: Icon(
                                      widget.controller.repeatMode ==
                                              PlayerRepeatMode.one
                                          ? Icons.repeat_one_rounded
                                          : Icons.repeat_rounded,
                                      color: widget.controller.repeatMode !=
                                              PlayerRepeatMode.off
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.42),
                                      size: 21,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // MOCHY BOTTOM PEEK DOCK (exact mochy_player.webp bottom bar!)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            18,
                            0,
                            18,
                            MediaQuery.of(context).padding.bottom + 8,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 0.7,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _DockTextAction(
                                  icon: Icons.lyrics_outlined,
                                  label: 'Lời bài hát',
                                  active: _showLyrics && !_videoMode,
                                  onTap: () {
                                    if (_videoMode) _toggleVideoMode(false);
                                    setState(() => _showLyrics = !_showLyrics);
                                    _maybeLoadLyrics();
                                  },
                                ),
                                _DockTextAction(
                                  icon: Icons.graphic_eq_rounded,
                                  label: 'Audio Lab',
                                  active: false,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => AudioLabScreen(
                                        controller: widget.controller,
                                        settingsController:
                                            widget.settingsController,
                                      ),
                                    ),
                                  ),
                                ),
                                _DockTextAction(
                                  icon: Icons.queue_music_rounded,
                                  label: 'Hàng đợi',
                                  active: false,
                                  onTap: () => _openQueueSheet(context, accent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isCenterBusy() {
    if (_videoMode) return _loadingVideo;
    return widget.controller.isLoadingStream || widget.controller.isBuffering;
  }

  bool _isCenterPlaying() {
    if (_videoMode) {
      return _videoCtrl?.value.isInitialized == true &&
          _videoCtrl!.value.isPlaying;
    }
    return widget.controller.isPlaying;
  }

  Future<void> _onPlayPauseTap() async {
    if (_videoMode) {
      final vc = _videoCtrl;
      if (vc == null || !vc.value.isInitialized) return;
      if (vc.value.isPlaying) {
        await vc.pause();
      } else {
        await vc.play();
      }
      if (mounted) setState(() {});
      return;
    }
    await widget.controller.togglePlayPause();
  }

  Widget _buildProgressBar(AppSettings settings, Color accent) {
    if (_videoMode && _videoCtrl?.value.isInitialized == true) {
      final val = _videoCtrl!.value;
      final totalMs = val.duration.inMilliseconds.clamp(1, 1 << 30);
      final frac = _dragSeekFraction ??
          (val.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
      return _sliderColumn(
        fraction: frac,
        bufferedFraction: frac,
        pos: Duration(milliseconds: (frac * totalMs).round()),
        total: val.duration,
        isPlaying: val.isPlaying,
        settings: settings,
        accent: accent,
        onSeek: (d) => _videoCtrl?.seekTo(d),
      );
    }

    return StreamBuilder<Duration>(
      stream: widget.controller.positionStream,
      initialData: widget.controller.currentPosition,
      builder: (context, posSnap) {
        return StreamBuilder<Duration>(
          stream: widget.controller.bufferedPositionStream,
          initialData: widget.controller.bufferedPosition,
          builder: (context, bufSnap) {
            final total = widget.controller.duration;
            final totalMs = total.inMilliseconds.clamp(1, 1 << 30);
            final pos = posSnap.data ?? Duration.zero;
            final buf = bufSnap.data ?? Duration.zero;
            final frac = _dragSeekFraction ??
                (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
            final bufFrac = (buf.inMilliseconds / totalMs).clamp(frac, 1.0);

            return _sliderColumn(
              fraction: frac,
              bufferedFraction: bufFrac,
              pos: Duration(milliseconds: (frac * totalMs).round()),
              total: total,
              isPlaying: widget.controller.isPlaying,
              settings: settings,
              accent: accent,
              onSeek: widget.controller.seek,
            );
          },
        );
      },
    );
  }

  Widget _sliderColumn({
    required double fraction,
    required double bufferedFraction,
    required Duration pos,
    required Duration total,
    required bool isPlaying,
    required AppSettings settings,
    required Color accent,
    required ValueChanged<Duration> onSeek,
  }) {
    return Column(
      children: [
        CustomMusicSlider(
          value: fraction,
          bufferedValue: bufferedFraction,
          isPlaying: isPlaying,
          style: settings.sliderStyle,
          accentColor: accent,
          onChanged: (f) => setState(() => _dragSeekFraction = f),
          onChangeEnd: (f) {
            final targetMs = (f * total.inMilliseconds).round();
            onSeek(Duration(milliseconds: targetMs));
            setState(() => _dragSeekFraction = null);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(pos),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _fmt(total),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoView(Color accent) {
    if (_loadingVideo) {
      return const Center(
        key: ValueKey('video_loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
            SizedBox(height: 12),
            Text(
              'Đang tải luồng Music Video...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_videoError != null ||
        _videoCtrl == null ||
        !_videoCtrl!.value.isInitialized) {
      return Center(
        key: const ValueKey('video_error'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded,
                  color: Colors.white60, size: 32),
              const SizedBox(height: 8),
              Text(
                _videoError ?? 'Không thể phát video cho bài hát này.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      key: const ValueKey('video_player'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: _videoCtrl!.value.aspectRatio > 0
                ? _videoCtrl!.value.aspectRatio
                : 16 / 9,
            child: VideoPlayer(_videoCtrl!),
          ),
        ),
      ),
    );
  }

  Widget _buildAltArtworkView(Track track, AppSettings settings, Color accent) {
    final scale = widget.controller.isPlaying ? 1.0 : 0.92;

    if (settings.playerStyle == PlayerStyle.vinyl) {
      return Center(
        key: const ValueKey('artwork_vinyl'),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutBack,
          child: AnimatedBuilder(
            animation: _vinylCtrl,
            builder: (_, child) => Transform.rotate(
              angle: _vinylCtrl.value * 2 * math.pi,
              child: child,
            ),
            child: Container(
              width: 288,
              height: 288,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0E0E12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _VinylGroovesPainter(),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Hero(
                        tag: 'now_playing_artwork_${track.id}',
                        child: ClipOval(
                          child: ArtworkImage(
                            url: track.artworkUrl,
                            size: 164,
                            radius: 82,
                          ),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0E0E12),
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Framed / Edge-to-Edge Card Artwork
    return Center(
      key: const ValueKey('artwork_framed'),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutBack,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: Hero(
              tag: 'now_playing_artwork_${track.id}',
              child: ArtworkImage(
                url: track.artworkUrl,
                size: 320,
                radius: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView(Track track, AppSettings settings, Color accent) {
    if (_loadingLyrics) {
      return const Center(
        key: ValueKey('lyrics_loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
            SizedBox(height: 10),
            Text(
              'Đang tìm lời bài hát...',
              style: TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    if (_lyricsResult.isEmpty) {
      return Center(
        key: const ValueKey('lyrics_empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chưa tìm thấy lời bài hát cho ca khúc này.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _openLyricsSourcePicker(context),
              icon: const Icon(Icons.hub_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Thử nguồn lời khác',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final lines = _lyricsResult.lines;
    final hasTimestamps = _lyricsResult.isSynced;
    final align = switch (settings.lyricsAlign) {
      LyricsAlign.left => TextAlign.left,
      LyricsAlign.center => TextAlign.center,
      LyricsAlign.right => TextAlign.right,
    };
    final crossAlign = switch (settings.lyricsAlign) {
      LyricsAlign.left => CrossAxisAlignment.start,
      LyricsAlign.center => CrossAxisAlignment.center,
      LyricsAlign.right => CrossAxisAlignment.end,
    };

    return StreamBuilder<Duration>(
      key: const ValueKey('lyrics_list'),
      stream: widget.controller.positionStream,
      initialData: widget.controller.currentPosition,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final activeIndex =
            hasTimestamps ? computeActiveLyricIndex(lines, pos) : -1;

        if (activeIndex >= 0 && activeIndex != _lastActiveLyricIndex) {
          _lastActiveLyricIndex = activeIndex;
          _scrollToLyricIndex(activeIndex);
        }

        return Column(
          children: [
            // Clean borderless Lyrics Toolbar
            Row(
              children: [
                GestureDetector(
                  onTap: () => _openLyricsSourcePicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasTimestamps
                              ? _lyricsResult.providerName
                              : '${_lyricsResult.providerName} · Lời thường',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SpringTap(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LyricsShareScreen(
                          track: track,
                          lyrics: lines,
                          initialIndex: activeIndex >= 0 ? activeIndex : 0,
                          profile: widget.settingsController.profile,
                          accentColor: accent,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Chia sẻ lời',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Open Borderless Apple Music / Mochy Synced Lyrics Viewport
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (notification.direction != ScrollDirection.idle &&
                          hasTimestamps) {
                        _onUserScrollLyrics();
                      }
                      return false;
                    },
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.10, 0.88, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                      ).createShader(bounds),
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        controller: _lyricsScroll,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 38),
                        child: Column(
                          crossAxisAlignment: crossAlign,
                          children: List.generate(lines.length, (i) {
                            final line = lines[i];
                            final isActive = i == activeIndex;
                            final isPast = activeIndex >= 0 && i < activeIndex;
                            final dist = activeIndex < 0
                                ? 0
                                : (i - activeIndex).abs();
                            final canSeek = line.time != null;

                            final targetColor = !hasTimestamps
                                ? Colors.white.withValues(alpha: 0.90)
                                : isActive
                                    ? Colors.white
                                    : isPast
                                        ? Colors.white.withValues(alpha: 0.30)
                                        : Colors.white.withValues(alpha: 0.50);

                            final blurSigma = (settings.blurInactiveLyrics &&
                                    hasTimestamps &&
                                    !isActive &&
                                    !_userScrollingLyrics)
                                ? (dist * 0.6).clamp(0.0, 2.0)
                                : 0.0;

                            final textWidget = AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontFamily:
                                    DefaultTextStyle.of(context).style.fontFamily,
                                color: targetColor,
                                fontSize: isActive
                                    ? settings.lyricsFontSize
                                    : (settings.lyricsFontSize -
                                            (hasTimestamps ? 3.0 : 2.0))
                                        .clamp(15.0, 24.0),
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                height: 1.36,
                                letterSpacing: -0.35,
                                shadows: isActive &&
                                        settings.lyricsStyle ==
                                            LyricsStyle.appleGlow
                                    ? [
                                        Shadow(
                                          color: Colors.white
                                              .withValues(alpha: 0.40),
                                          blurRadius: 16,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(line.text, textAlign: align),
                            );

                            Widget lineBody = Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 4,
                              ),
                              child: blurSigma > 0.25
                                  ? ImageFiltered(
                                      imageFilter: ImageFilter.blur(
                                        sigmaX: blurSigma,
                                        sigmaY: blurSigma,
                                      ),
                                      child: textWidget,
                                    )
                                  : textWidget,
                            );

                            if (isActive &&
                                settings.lyricsStyle ==
                                    LyricsStyle.karaokePill) {
                              lineBody = AnimatedContainer(
                                duration: const Duration(milliseconds: 240),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                                child: lineBody,
                              );
                            } else if (hasTimestamps &&
                                settings.lyricsStyle ==
                                    LyricsStyle.mochyMotion) {
                              lineBody = AnimatedScale(
                                scale: isActive ? 1.04 : 0.96,
                                alignment: switch (settings.lyricsAlign) {
                                  LyricsAlign.left => Alignment.centerLeft,
                                  LyricsAlign.center => Alignment.center,
                                  LyricsAlign.right => Alignment.centerRight,
                                },
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                child: lineBody,
                              );
                            }

                            return KeyedSubtree(
                              key: i < _lyricKeys.length ? _lyricKeys[i] : null,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: canSeek
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        setState(
                                            () => _userScrollingLyrics = false);
                                        _resumeAutoScrollTimer?.cancel();
                                        widget.controller.seek(line.time!);
                                        _scrollToLyricIndex(i, force: true);
                                      }
                                    : null,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: lineBody,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                  if (_userScrollingLyrics && activeIndex >= 0)
                    Positioned(
                      bottom: 8,
                      right: 4,
                      child: SpringTap(
                        onTap: () {
                          _resumeAutoScrollTimer?.cancel();
                          setState(() => _userScrollingLyrics = false);
                          _scrollToLyricIndex(activeIndex, force: true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location_rounded,
                                  size: 13, color: Colors.black),
                              SizedBox(width: 5),
                              Text(
                                'Về câu đang hát',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
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
          ],
        );
      },
    );
  }

  void _openQuickCustomiseSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final s = widget.settingsController.settings;
            final accent = s.accentColor;
            final onAccent = s.onAccentColor;

            Widget chip(String label, bool sel, VoidCallback onTap) {
              return SpringTap(
                onTap: () {
                  onTap();
                  setModalState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: sel ? accent : const Color(0xFF26262B),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: sel ? onAccent : const Color(0xFFAEAEB2),
                      fontSize: 12.5,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF16161A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tuỳ chỉnh trực tiếp',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Chế độ giao diện',
                        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip(
                          'Liquid Glass',
                          s.visualTheme == AppVisualTheme.liquidGlass,
                          () => widget.settingsController
                              .setVisualTheme(AppVisualTheme.liquidGlass),
                        ),
                        chip(
                          'Classic',
                          s.visualTheme == AppVisualTheme.classic,
                          () => widget.settingsController
                              .setVisualTheme(AppVisualTheme.classic),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Mẫu hiển thị',
                        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip(
                          'Mochy Flagship',
                          s.playerStyle == PlayerStyle.flagship,
                          () => widget.settingsController
                              .setPlayerStyle(PlayerStyle.flagship),
                        ),
                        chip(
                          'Đĩa Vinyl xoay',
                          s.playerStyle == PlayerStyle.vinyl,
                          () => widget.settingsController
                              .setPlayerStyle(PlayerStyle.vinyl),
                        ),
                        chip(
                          'Bìa vuông',
                          s.playerStyle == PlayerStyle.edgeToEdge,
                          () => widget.settingsController
                              .setPlayerStyle(PlayerStyle.edgeToEdge),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Thanh tua nhạc',
                        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip(
                          'Apple / Mochy',
                          s.sliderStyle == SliderStyle.appleSlim,
                          () => widget.settingsController
                              .setSliderStyle(SliderStyle.appleSlim),
                        ),
                        chip(
                          'Sóng Mochy',
                          s.sliderStyle == SliderStyle.mochyWavy,
                          () => widget.settingsController
                              .setSliderStyle(SliderStyle.mochyWavy),
                        ),
                        chip(
                          'Liquid Pill',
                          s.sliderStyle == SliderStyle.liquidPill,
                          () => widget.settingsController
                              .setSliderStyle(SliderStyle.liquidPill),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Hiệu ứng lời bài hát',
                        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip(
                          'Apple Glow',
                          s.lyricsStyle == LyricsStyle.appleGlow,
                          () => widget.settingsController
                              .setLyricsStyle(LyricsStyle.appleGlow),
                        ),
                        chip(
                          'Mochy Motion',
                          s.lyricsStyle == LyricsStyle.mochyMotion,
                          () => widget.settingsController
                              .setLyricsStyle(LyricsStyle.mochyMotion),
                        ),
                        chip(
                          'Karaoke',
                          s.lyricsStyle == LyricsStyle.karaokePill,
                          () => widget.settingsController
                              .setLyricsStyle(LyricsStyle.karaokePill),
                        ),
                        chip(
                          'Tối giản',
                          s.lyricsStyle == LyricsStyle.minimal,
                          () => widget.settingsController
                              .setLyricsStyle(LyricsStyle.minimal),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openLyricsSourcePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF16161A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn nguồn lời bài hát',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...AppSettings.defaultLyricsProviders.map((id) {
                final active = _lyricsResult.providerId == id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.hub_rounded,
                    color: active ? Colors.white : const Color(0xFF636366),
                  ),
                  title: Text(
                    AppSettings.providerDisplayNames[id] ?? id,
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFFAEAEB2),
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: active
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _maybeLoadLyrics(forceProvider: id);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openQueueSheet(BuildContext context, Color accent) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.88,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF141418),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Danh sách phát tiếp theo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: widget.controller.queue.length,
                      itemBuilder: (_, idx) {
                        final item = widget.controller.queue[idx];
                        return TrackTile(
                          track: item,
                          isCurrent: idx == widget.controller.currentIndex,
                          isPlaying: widget.controller.isPlaying,
                          isFavorite: widget.controller.isFavorite(item.id),
                          accentColor: accent,
                          onTap: () {
                            widget.controller.playAtIndex(idx);
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: active
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DockTextAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DockTextAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.62),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color:
                  active ? Colors.white : Colors.white.withValues(alpha: 0.62),
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.white.withValues(alpha: 0.08);
    for (double r = maxR * 0.62; r < maxR - 4; r += 5.5) {
      canvas.drawCircle(center, r, groovePaint);
    }
    final sheen = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.12),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, maxR - 1, sheen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
