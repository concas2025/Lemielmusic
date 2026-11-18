import 'package:material_ui/material_ui.dart';
import '../models/track.dart';
import '../services/lyrics_service.dart';
import '../services/player_controller.dart';
import '../widgets/glass.dart';

class NowPlayingScreen extends StatefulWidget {
  final PlayerController controller;
  final LyricsService lyricsService;

  const NowPlayingScreen({
    super.key,
    required this.controller,
    required this.lyricsService,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _showLyrics = false;
  String? _lyricsTrackId;
  bool _loadingLyrics = false;
  List<LyricLine> _lyrics = [];
  final ScrollController _lyricsScroll = ScrollController();
  double? _dragSeekMs;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPlayerUpdate);
    _maybeLoadLyrics();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPlayerUpdate);
    _lyricsScroll.dispose();
    super.dispose();
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    setState(() {});
    _maybeLoadLyrics();
  }

  Future<void> _maybeLoadLyrics() async {
    final track = widget.controller.currentTrack;
    if (!_showLyrics || track == null || _lyricsTrackId == track.id) return;
    _lyricsTrackId = track.id;
    setState(() {
      _loadingLyrics = true;
      _lyrics = [];
    });
    final lines = await widget.lyricsService.fetchLyrics(track);
    if (!mounted || _lyricsTrackId != track.id) return;
    setState(() {
      _lyrics = lines;
      _loadingLyrics = false;
    });
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
      return const Scaffold(backgroundColor: Color(0xFF07070B));
    }

    final isFav = widget.controller.isFavorite(track.id);
    const accent = Color(0xFFFF375F);

    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 450) {
            Navigator.of(context).pop();
          }
        },
        child: AmbientBackground(
          artworkUrl: track.artworkUrl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Top grabber & header
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70,
                          size: 30,
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'LEMIELMUSIC',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Đang phát',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => _openQueueSheet(context),
                        icon: const Icon(
                          Icons.queue_music_rounded,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Center Artwork OR Synced Lyrics
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _showLyrics
                          ? _buildLyricsView()
                          : _buildArtworkView(track),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Title, Artist & Favorite
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
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => widget.controller.toggleFavorite(track),
                        icon: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? accent : Colors.white70,
                          size: 26,
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

                  // Progress scrubber
                  StreamBuilder<Duration>(
                    stream: widget.controller.positionStream,
                    initialData: widget.controller.currentPosition,
                    builder: (context, snap) {
                      final totalMs = widget.controller.duration.inMilliseconds
                          .toDouble()
                          .clamp(1.0, double.infinity);
                      final posMs = (_dragSeekMs ??
                              (snap.data ?? Duration.zero)
                                  .inMilliseconds
                                  .toDouble())
                          .clamp(0.0, totalMs);

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor:
                                  Colors.white.withValues(alpha: 0.18),
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: posMs,
                              min: 0,
                              max: totalMs,
                              onChanged: (v) => setState(() => _dragSeekMs = v),
                              onChangeEnd: (v) {
                                widget.controller.seek(
                                  Duration(milliseconds: v.round()),
                                );
                                setState(() => _dragSeekMs = null);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fmt(Duration(milliseconds: posMs.round())),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                Text(
                                  _fmt(widget.controller.duration),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // Playback controls
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
                      IconButton(
                        onPressed: widget.controller.previous,
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.controller.togglePlayPause,
                        child: GlassSurface(
                          borderRadius: 40,
                          blur: 20,
                          opacity: 0.22,
                          padding: const EdgeInsets.all(18),
                          child: widget.controller.isLoadingStream ||
                                  widget.controller.isBuffering
                              ? const SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  widget.controller.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => widget.controller.next(),
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 38,
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

                  const SizedBox(height: 14),

                  // Bottom action pills (Lyrics toggle + Queue)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => _showLyrics = !_showLyrics);
                          _maybeLoadLyrics();
                        },
                        child: GlassSurface(
                          borderRadius: 20,
                          opacity: _showLyrics ? 0.24 : 0.09,
                          tintColor: _showLyrics ? accent : Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lyrics_rounded,
                                size: 17,
                                color: _showLyrics
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Lời bài hát',
                                style: TextStyle(
                                  color: _showLyrics
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkView(Track track) {
    final scale = widget.controller.isPlaying ? 1.0 : 0.90;
    return Center(
      key: const ValueKey('artwork_view'),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutBack,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 36,
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
                radius: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView() {
    if (_loadingLyrics) {
      return const Center(
        key: ValueKey('lyrics_loading'),
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    if (_lyrics.isEmpty) {
      return Center(
        key: const ValueKey('lyrics_empty'),
        child: GlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(
            'Chưa tìm thấy lời bài hát cho ca khúc này.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      key: const ValueKey('lyrics_list'),
      stream: widget.controller.positionStream,
      initialData: widget.controller.currentPosition,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        int activeIndex = -1;
        for (int i = 0; i < _lyrics.length; i++) {
          final t = _lyrics[i].time;
          if (t != null && pos >= t) {
            activeIndex = i;
          }
        }

        return GlassSurface(
          borderRadius: 24,
          opacity: 0.08,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: ListView.builder(
            controller: _lyricsScroll,
            itemCount: _lyrics.length,
            itemBuilder: (context, i) {
              final line = _lyrics[i];
              final isActive = i == activeIndex;
              return GestureDetector(
                onTap: line.time != null
                    ? () => widget.controller.seek(line.time!)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.42),
                      fontSize: isActive ? 20 : 16,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      height: 1.35,
                    ),
                    child: Text(line.text),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openQueueSheet(BuildContext context) {
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
              blur: 32,
              opacity: 0.16,
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
