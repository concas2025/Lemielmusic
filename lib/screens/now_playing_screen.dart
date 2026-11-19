import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import '../models/app_settings.dart';
import '../models/track.dart';
import '../services/lyrics_service.dart';
import '../services/player_controller.dart';
import '../services/settings_controller.dart';
import '../widgets/glass.dart';
import '../widgets/wavy_slider.dart';
import 'audio_lab_screen.dart';
import 'lyrics_share_screen.dart';

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
  int _lastActiveLyricIndex = -1;
  final ScrollController _lyricsScroll = ScrollController();

  double? _dragSeekFraction;
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
    _maybeLoadLyrics();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPlayerUpdate);
    widget.settingsController.removeListener(_onSettingsUpdate);
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

    setState(() {});
    _maybeLoadLyrics();
  }

  Future<void> _maybeLoadLyrics({String? forceProvider}) async {
    final track = widget.controller.currentTrack;
    if (!_showLyrics || track == null) return;
    if (forceProvider == null && _lyricsTrackId == track.id) return;

    _lyricsTrackId = track.id;
    _lastActiveLyricIndex = -1;
    setState(() {
      _loadingLyrics = true;
      _lyricsResult = LyricsResult.empty;
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
      _loadingLyrics = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final track = widget.controller.currentTrack;
    if (track == null) {
      return const Scaffold(backgroundColor: Color(0xFF06060A));
    }

    final settings = widget.settingsController.settings;
    final accent = settings.accentColor;
    final isFav = widget.controller.isFavorite(track.id);

    return Scaffold(
      backgroundColor: const Color(0xFF06060A),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 460) {
            _disposeVideo(resumeAudio: _videoMode);
            Navigator.of(context).pop();
          }
        },
        child: AmbientBackground(
          artworkUrl: track.artworkUrl,
          accentColor: accent,
          style: settings.backgroundStyle,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Top header: Down button | Song / Video Toggle | Quick Customise + Queue
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          _disposeVideo(resumeAudio: _videoMode);
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70,
                          size: 30,
                        ),
                      ),
                      const Spacer(),
                      // YouTube Music style Bài hát | Video pill
                      GlassSurface(
                        borderRadius: 20,
                        blur: 16,
                        opacity: 0.12,
                        highQuality: settings.highGlass,
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ModeTab(
                              label: 'Bài hát',
                              active: !_videoMode,
                              accent: accent,
                              onTap: () => _toggleVideoMode(false),
                            ),
                            _ModeTab(
                              label: 'Video',
                              active: _videoMode,
                              accent: accent,
                              onTap: () => _toggleVideoMode(true),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Tuỳ chỉnh trực tiếp',
                        onPressed: () => _openQuickCustomiseSheet(context),
                        icon: Icon(
                          Icons.tune_rounded,
                          color: Colors.white.withValues(alpha: 0.84),
                          size: 23,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Center Stage: Video Player OR Lyrics OR Artwork (3 Styles)
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      child: _videoMode
                          ? _buildVideoView(accent)
                          : _showLyrics
                              ? _buildLyricsView(track, settings, accent)
                              : _buildArtworkView(track, settings, accent),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title, Artist, Favorite & Share Lyrics shortcut
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.64),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (widget.controller.isCurrentTrackCached &&
                                    !_videoMode) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 14,
                                    color: accent.withValues(alpha: 0.85),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      SpringTap(
                        onTap: () => widget.controller.toggleFavorite(track),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFav ? accent : Colors.white70,
                            size: 27,
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
                          color: Color(0xFFFF6961),
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Progress Scrubber (isolated RepaintBoundary + custom SliderStyle)
                  RepaintBoundary(
                    child: _buildProgressBar(settings, accent),
                  ),

                  const SizedBox(height: 12),

                  // Main Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: widget.controller.toggleShuffle,
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: widget.controller.shuffle
                              ? accent
                              : Colors.white.withValues(alpha: 0.55),
                          size: 22,
                        ),
                      ),
                      SpringTap(
                        onTap: widget.controller.previous,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                      SpringTap(
                        pressedScale: 0.90,
                        onTap: _onPlayPauseTap,
                        child: GlassSurface(
                          borderRadius: 42,
                          blur: 20,
                          opacity: 0.22,
                          tintColor: accent,
                          isLens: true,
                          highQuality: settings.highGlass,
                          padding: const EdgeInsets.all(18),
                          child: _isCenterBusy()
                              ? const SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  transitionBuilder: (c, a) =>
                                      ScaleTransition(scale: a, child: c),
                                  child: Icon(
                                    _isCenterPlaying()
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    key: ValueKey(_isCenterPlaying()),
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                        ),
                      ),
                      SpringTap(
                        onTap: () => widget.controller.next(),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.controller.cycleRepeatMode,
                        icon: Icon(
                          widget.controller.repeatMode == PlayerRepeatMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: widget.controller.repeatMode !=
                                  PlayerRepeatMode.off
                              ? accent
                              : Colors.white.withValues(alpha: 0.55),
                          size: 22,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Bottom Liquid Glass Utility Bar: Lyrics | Audio Lab | Queue
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _UtilityPill(
                        icon: Icons.lyrics_rounded,
                        label: 'Lời bài hát',
                        active: _showLyrics && !_videoMode,
                        accent: accent,
                        highGlass: settings.highGlass,
                        onTap: () {
                          if (_videoMode) _toggleVideoMode(false);
                          setState(() => _showLyrics = !_showLyrics);
                          _maybeLoadLyrics();
                        },
                      ),
                      const SizedBox(width: 8),
                      _UtilityPill(
                        icon: Icons.graphic_eq_rounded,
                        label: 'Audio Lab',
                        active: false,
                        accent: accent,
                        highGlass: settings.highGlass,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AudioLabScreen(
                              controller: widget.controller,
                              settingsController: widget.settingsController,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _UtilityPill(
                        icon: Icons.queue_music_rounded,
                        label: 'Hàng đợi',
                        active: false,
                        accent: accent,
                        highGlass: settings.highGlass,
                        onTap: () => _openQueueSheet(context, accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
      builder: (context, snap) {
        final total = widget.controller.duration;
        final totalMs = total.inMilliseconds.clamp(1, 1 << 30);
        final pos = snap.data ?? Duration.zero;
        final frac = _dragSeekFraction ??
            (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
        return _sliderColumn(
          fraction: frac,
          pos: Duration(milliseconds: (frac * totalMs).round()),
          total: total,
          isPlaying: widget.controller.isPlaying,
          settings: settings,
          accent: accent,
          onSeek: widget.controller.seek,
        );
      },
    );
  }

  Widget _sliderColumn({
    required double fraction,
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(pos),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _fmt(total),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 12,
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
      return Center(
        key: const ValueKey('video_loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: accent),
            const SizedBox(height: 12),
            const Text(
              'Đang tải luồng Music Video...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_videoError != null || _videoCtrl == null || !_videoCtrl!.value.isInitialized) {
      return Center(
        key: const ValueKey('video_error'),
        child: GlassSurface(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white60, size: 34),
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
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
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

  Widget _buildArtworkView(Track track, AppSettings settings, Color accent) {
    final scale = widget.controller.isPlaying ? 1.0 : 0.91;

    if (settings.playerStyle == PlayerStyle.vinyl) {
      return Center(
        key: const ValueKey('artwork_vinyl'),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          child: AnimatedBuilder(
            animation: _vinylCtrl,
            builder: (_, child) => Transform.rotate(
              angle: _vinylCtrl.value * 2 * math.pi,
              child: child,
            ),
            child: Container(
              width: 295,
              height: 295,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0E0E13),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 38,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 28,
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
                      ClipOval(
                        child: ArtworkImage(
                          url: track.artworkUrl,
                          size: 168,
                          radius: 84,
                        ),
                      ),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0D0D12),
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

    if (settings.playerStyle == PlayerStyle.edgeToEdge) {
      return Center(
        key: const ValueKey('artwork_edge'),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArtworkImage(url: track.artworkUrl, size: 380, radius: 28),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1.0,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.36),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Default: Flagship Liquid Glass Framed Artwork
    return Center(
      key: const ValueKey('artwork_flagship'),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 324, maxHeight: 324),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 42,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.56),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: Hero(
              tag: 'now_playing_artwork_${track.id}',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                    width: 1.1,
                  ),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: ArtworkImage(
                  url: track.artworkUrl,
                  size: 316,
                  radius: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView(Track track, AppSettings settings, Color accent) {
    if (_loadingLyrics) {
      return Center(
        key: const ValueKey('lyrics_loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: accent),
            const SizedBox(height: 10),
            const Text(
              'Đang tìm lời bài hát từ các nguồn...',
              style: TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    if (_lyricsResult.isEmpty) {
      return Center(
        key: const ValueKey('lyrics_empty'),
        child: GlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chưa tìm thấy lời bài hát cho ca khúc này.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _openLyricsSourcePicker(context),
                icon: Icon(Icons.hub_rounded, size: 16, color: accent),
                label: Text(
                  'Thử nguồn lời khác',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lines = _lyricsResult.lines;
    final align = switch (settings.lyricsAlign) {
      LyricsAlign.left => TextAlign.left,
      LyricsAlign.center => TextAlign.center,
      LyricsAlign.right => TextAlign.right,
    };

    return StreamBuilder<Duration>(
      key: const ValueKey('lyrics_list'),
      stream: widget.controller.positionStream,
      initialData: widget.controller.currentPosition,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        int activeIndex = -1;
        for (int i = 0; i < lines.length; i++) {
          final t = lines[i].time;
          if (t != null && pos >= t) {
            activeIndex = i;
          }
        }

        // Smoothly auto-scroll to active lyric line when it advances.
        if (activeIndex >= 0 &&
            activeIndex != _lastActiveLyricIndex &&
            _lyricsScroll.hasClients) {
          _lastActiveLyricIndex = activeIndex;
          final targetOffset = (activeIndex * 54.0 - 95.0).clamp(
            0.0,
            _lyricsScroll.position.maxScrollExtent,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_lyricsScroll.hasClients) {
              _lyricsScroll.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }

        return GlassSurface(
          borderRadius: 26,
          blur: 18,
          opacity: 0.09,
          highQuality: settings.highGlass,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Top Lyrics Toolbar: Provider Badge + Switch Source + Share Card Button
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
                        color: Colors.white.withValues(alpha: 0.09),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hub_rounded, size: 13, color: accent),
                          const SizedBox(width: 5),
                          Text(
                            'Nguồn: ${_lyricsResult.providerName}',
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
                        color: accent.withValues(alpha: 0.25),
                        border: Border.all(color: accent.withValues(alpha: 0.5)),
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
              const SizedBox(height: 8),

              // Lyrics Lines List
              Expanded(
                child: ListView.builder(
                  controller: _lyricsScroll,
                  physics: const BouncingScrollPhysics(),
                  itemCount: lines.length,
                  itemBuilder: (context, i) {
                    final line = lines[i];
                    final isActive = i == activeIndex;
                    final dist = activeIndex < 0 ? 0 : (i - activeIndex).abs();
                    final blurSigma = (settings.blurInactiveLyrics &&
                            _lyricsResult.isSynced &&
                            !isActive)
                        ? (dist * 0.7).clamp(0.0, 2.2)
                        : 0.0;

                    final textWidget = AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: isActive || !_lyricsResult.isSynced
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.40),
                        fontSize: isActive
                            ? settings.lyricsFontSize
                            : (settings.lyricsFontSize - 3.5).clamp(14.0, 24.0),
                        fontWeight:
                            isActive ? FontWeight.w800 : FontWeight.w500,
                        height: 1.34,
                        shadows: isActive &&
                                settings.lyricsStyle == LyricsStyle.appleGlow
                            ? [
                                Shadow(
                                  color: accent.withValues(alpha: 0.65),
                                  blurRadius: 14,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(line.text, textAlign: align),
                    );

                    Widget styledLine = Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 6,
                      ),
                      child: blurSigma > 0.2
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
                        settings.lyricsStyle == LyricsStyle.karaokePill) {
                      styledLine = AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: accent.withValues(alpha: 0.22),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.48),
                          ),
                        ),
                        child: styledLine,
                      );
                    } else if (settings.lyricsStyle == LyricsStyle.mochyMotion) {
                      styledLine = AnimatedScale(
                        scale: isActive ? 1.03 : 0.96,
                        alignment: switch (settings.lyricsAlign) {
                          LyricsAlign.left => Alignment.centerLeft,
                          LyricsAlign.center => Alignment.center,
                          LyricsAlign.right => Alignment.centerRight,
                        },
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        child: styledLine,
                      );
                    }

                    return GestureDetector(
                      onTap: line.time != null
                          ? () => widget.controller.seek(line.time!)
                          : null,
                      child: styledLine,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mochy-style Live Customisation Sheet directly inside Now Playing!
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

            Widget chip(String label, bool sel, VoidCallback onTap) {
              return SpringTap(
                onTap: () {
                  onTap();
                  setModalState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: sel
                        ? accent.withValues(alpha: 0.30)
                        : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: sel ? accent : Colors.white12),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: sel ? Colors.white : Colors.white70,
                      fontSize: 12.5,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            return GlassSurface(
              borderRadius: 28,
              blur: 28,
              opacity: 0.22,
              tintColor: const Color(0xFF14141E),
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
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tuỳ chỉnh trực tiếp trình phát',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Mẫu hiển thị', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip('Flagship Glass', s.playerStyle == PlayerStyle.flagship,
                            () => widget.settingsController.setPlayerStyle(PlayerStyle.flagship)),
                        chip('Đĩa Vinyl xoay', s.playerStyle == PlayerStyle.vinyl,
                            () => widget.settingsController.setPlayerStyle(PlayerStyle.vinyl)),
                        chip('Tràn viền', s.playerStyle == PlayerStyle.edgeToEdge,
                            () => widget.settingsController.setPlayerStyle(PlayerStyle.edgeToEdge)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Nền trình phát', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip('Ánh sáng nền', s.backgroundStyle == PlayerBackgroundStyle.ambientGlow,
                            () => widget.settingsController.setBackgroundStyle(PlayerBackgroundStyle.ambientGlow)),
                        chip('Apple Blur', s.backgroundStyle == PlayerBackgroundStyle.appleBlur,
                            () => widget.settingsController.setBackgroundStyle(PlayerBackgroundStyle.appleBlur)),
                        chip('Tối giản', s.backgroundStyle == PlayerBackgroundStyle.darkGradient,
                            () => widget.settingsController.setBackgroundStyle(PlayerBackgroundStyle.darkGradient)),
                        chip('Đen OLED', s.backgroundStyle == PlayerBackgroundStyle.oledBlack,
                            () => widget.settingsController.setBackgroundStyle(PlayerBackgroundStyle.oledBlack)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Thanh tua nhạc', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip('Sóng Mochy', s.sliderStyle == SliderStyle.mochyWavy,
                            () => widget.settingsController.setSliderStyle(SliderStyle.mochyWavy)),
                        chip('Apple Slim', s.sliderStyle == SliderStyle.appleSlim,
                            () => widget.settingsController.setSliderStyle(SliderStyle.appleSlim)),
                        chip('Liquid Pill', s.sliderStyle == SliderStyle.liquidPill,
                            () => widget.settingsController.setSliderStyle(SliderStyle.liquidPill)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Hiệu ứng lời bài hát', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        chip('Apple Glow', s.lyricsStyle == LyricsStyle.appleGlow,
                            () => widget.settingsController.setLyricsStyle(LyricsStyle.appleGlow)),
                        chip('Mochy Motion', s.lyricsStyle == LyricsStyle.mochyMotion,
                            () => widget.settingsController.setLyricsStyle(LyricsStyle.mochyMotion)),
                        chip('Karaoke', s.lyricsStyle == LyricsStyle.karaokePill,
                            () => widget.settingsController.setLyricsStyle(LyricsStyle.karaokePill)),
                        chip('Tối giản', s.lyricsStyle == LyricsStyle.minimal,
                            () => widget.settingsController.setLyricsStyle(LyricsStyle.minimal)),
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
    final accent = widget.settingsController.settings.accentColor;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassSurface(
          borderRadius: 26,
          blur: 26,
          opacity: 0.22,
          tintColor: const Color(0xFF14141D),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn nguồn lời cho bài hát này',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...AppSettings.defaultLyricsProviders.map((id) {
                final active = _lyricsResult.providerId == id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.hub_rounded,
                    color: active ? accent : Colors.white54,
                  ),
                  title: Text(
                    AppSettings.providerDisplayNames[id] ?? id,
                    style: TextStyle(
                      color: active ? accent : Colors.white,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: active
                      ? Icon(Icons.check_rounded, color: accent)
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
            return GlassSurface(
              borderRadius: 28,
              blur: 28,
              opacity: 0.20,
              tintColor: const Color(0xFF14141D),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
  final Color accent;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: active ? accent.withValues(alpha: 0.35) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _UtilityPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color accent;
  final bool highGlass;
  final VoidCallback onTap;

  const _UtilityPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.highGlass,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: GlassSurface(
        borderRadius: 20,
        blur: 16,
        opacity: active ? 0.28 : 0.10,
        tintColor: active ? accent : Colors.white,
        highQuality: highGlass,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.white70),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
    // Vinyl light specular sweep
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
