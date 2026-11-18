import 'package:material_ui/material_ui.dart';
import '../models/track.dart';
import '../services/player_controller.dart';
import '../services/ytm_service.dart';
import '../widgets/glass.dart';

class HomeScreen extends StatefulWidget {
  final PlayerController controller;
  final YtmService ytm;
  final VoidCallback onSearchTap;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.ytm,
    required this.onSearchTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _moods = [
    ('trending', 'Thịnh hành'),
    ('chill', 'Chill'),
    ('usuk', 'US-UK'),
    ('ballad', 'Ballad'),
    ('lofi', 'Lofi'),
  ];

  String _selectedMood = 'trending';
  bool _loading = true;
  String? _error;
  List<Track> _tracks = [];

  @override
  void initState() {
    super.initState();
    _loadMood(_selectedMood);
  }

  Future<void> _loadMood(String mood, {bool force = false}) async {
    setState(() {
      _selectedMood = mood;
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.ytm.fetchMoodTracks(mood, force: force);
      if (!mounted || _selectedMood != mood) return;
      setState(() {
        _tracks = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _selectedMood != mood) return;
      setState(() {
        _loading = false;
        _error = 'Không thể tải danh sách nhạc. Kéo xuống để thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.controller.currentTrack;
    final history = widget.controller.history;

    return RefreshIndicator(
      color: const Color(0xFFFF375F),
      backgroundColor: const Color(0xFF16161F),
      onRefresh: () => _loadMood(_selectedMood, force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NGHE NGAY',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Lemielmusic',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: widget.onSearchTap,
                    child: const GlassSurface(
                      borderRadius: 20,
                      opacity: 0.10,
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Mood selector pills
          SliverToBoxAdapter(
            child: SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _moods.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (key, label) = _moods[i];
                  final active = key == _selectedMood;
                  return GestureDetector(
                    onTap: () => _loadMood(key),
                    child: Center(
                      child: GlassSurface(
                        borderRadius: 20,
                        opacity: active ? 0.28 : 0.08,
                        tintColor:
                            active ? const Color(0xFFFF375F) : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Recently played shelf
          if (history.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Text(
                  'Nghe gần đây',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 158,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: history.take(10).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final item = history[i];
                    return GestureDetector(
                      onTap: () =>
                          widget.controller.playTrack(item, queue: history),
                      child: SizedBox(
                        width: 112,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ArtworkImage(
                              url: item.artworkUrl,
                              size: 112,
                              radius: 16,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Gợi ý cho bạn',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF375F)),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 160),
              sliver: SliverList.builder(
                itemCount: _tracks.length,
                itemBuilder: (_, i) {
                  final track = _tracks[i];
                  return TrackTile(
                    track: track,
                    isCurrent: current?.id == track.id,
                    isPlaying: widget.controller.isPlaying,
                    isFavorite: widget.controller.isFavorite(track.id),
                    onTap: () =>
                        widget.controller.playTrack(track, queue: _tracks),
                    onFavoriteTap: () =>
                        widget.controller.toggleFavorite(track),
                    onAddQueue: () {
                      widget.controller.addToQueue(track);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã thêm "${track.title}" vào hàng đợi'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
