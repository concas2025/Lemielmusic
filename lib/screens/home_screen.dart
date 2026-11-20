import 'package:material_ui/material_ui.dart';
import '../models/track.dart';
import '../services/import_service.dart';
import '../services/player_controller.dart';
import '../services/settings_controller.dart';
import '../services/ytm_service.dart';
import '../widgets/glass.dart';
import '../widgets/profile_id_card.dart';
import 'audio_lab_screen.dart';
import 'customisation_screen.dart';
import 'library_screen.dart';

/// BitChord / Apple Music editorial dark Home Screen:
/// Pure OLED black canvas, monochrome white/graphite typography, horizontal
/// swipeable Quick Picks columns, borderless large square artwork shelves,
/// and zero cluttered borders or garish red blobs.
class HomeScreen extends StatefulWidget {
  final PlayerController controller;
  final SettingsController settingsController;
  final YtmService ytm;
  final ImportService importService;
  final VoidCallback onProfileTap;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.ytm,
    required this.importService,
    required this.onProfileTap,
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
  late final PageController _quickPicksCtrl;

  @override
  void initState() {
    super.initState();
    _quickPicksCtrl = PageController(viewportFraction: 0.90);
    _loadMood(_selectedMood);
  }

  @override
  void dispose() {
    _quickPicksCtrl.dispose();
    super.dispose();
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
    final settings = widget.settingsController.settings;
    final profile = widget.settingsController.profile;
    final accent = settings.accentColor;
    final onAccent = settings.onAccentColor;

    // Split tracks into Quick Picks (first 12 in 3 swipeable 4-row columns) and More
    final quickPicks = _tracks.take(12).toList(growable: false);
    final quickPages = (quickPicks.length / 4).ceil();
    final remaining = _tracks.length > 12 ? _tracks.sublist(12) : const <Track>[];

    return RefreshIndicator(
      color: accent,
      backgroundColor: const Color(0xFF1C1C1E),
      onRefresh: () => _loadMood(_selectedMood, force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Clean BitChord / Apple Music Editorial Top Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Trang chủ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                      ),
                    ),
                  ),
                  SpringTap(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AudioLabScreen(
                          controller: widget.controller,
                          settingsController: widget.settingsController,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1C1C1E),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SpringTap(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CustomisationScreen(
                          settingsController: widget.settingsController,
                          previewArtworkUrl: current?.artworkUrl,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1C1C1E),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SpringTap(
                    onTap: widget.onProfileTap,
                    child: ProfileAvatar(
                      profile: profile,
                      accentColor: accent,
                      size: 38,
                      neutralMonochrome: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BitChord Monochrome Mood Filter Pills
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _moods.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (key, label) = _moods[i];
                  final active = key == _selectedMood;
                  return SpringTap(
                    onTap: () => _loadMood(key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: active ? accent : const Color(0xFF1C1C1E),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: active ? onAccent : const Color(0xFFAEAEB2),
                          fontSize: 13.5,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Recently Played — BitChord / Apple Music Borderless Large Square Shelf
          if (history.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  'Nghe gần đây',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 196,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: history.take(10).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final item = history[i];
                    return SpringTap(
                      onTap: () =>
                          widget.controller.playTrack(item, queue: history),
                      child: SizedBox(
                        width: 144,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ArtworkImage(
                              url: item.artworkUrl,
                              size: 144,
                              radius: 14,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              item.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 12,
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

          // Quick Picks Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chọn nhanh cho bạn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (_tracks.isNotEmpty)
                    SpringTap(
                      onTap: () => widget.controller
                          .playTrack(_tracks.first, queue: _tracks),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF1C1C1E),
                        ),
                        child: const Text(
                          'Phát tất cả',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
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
                    style: const TextStyle(color: Color(0xFF8E8E93)),
                  ),
                ),
              ),
            )
          else ...[
            // BitChord / Apple Music 4-Row Horizontal Swipeable Quick Picks
            SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: PageView.builder(
                  controller: _quickPicksCtrl,
                  padEnds: false,
                  itemCount: quickPages,
                  itemBuilder: (_, pageIdx) {
                    final start = pageIdx * 4;
                    final slice = quickPicks.skip(start).take(4).toList();
                    return Padding(
                      padding: EdgeInsets.only(
                        left: pageIdx == 0 ? 10 : 4,
                        right: 4,
                      ),
                      child: Column(
                        children: slice.asMap().entries.map((entry) {
                          final track = entry.value;
                          final isLast = entry.key == slice.length - 1;
                          return TrackTile(
                            track: track,
                            isCurrent: current?.id == track.id,
                            isPlaying: widget.controller.isPlaying,
                            isFavorite: widget.controller.isFavorite(track.id),
                            accentColor: accent,
                            showDivider: !isLast,
                            onTap: () => widget.controller
                                .playTrack(track, queue: _tracks),
                            onFavoriteTap: () =>
                                widget.controller.toggleFavorite(track),
                            onAddToPlaylist: () => showAddToPlaylistSheet(
                              context,
                              controller: widget.controller,
                              track: track,
                              accentColor: accent,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),

            // More Tracks Shelf
            if (remaining.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    'Khám phá thêm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 175),
                sliver: SliverList.builder(
                  itemCount: remaining.length,
                  itemBuilder: (_, i) {
                    final track = remaining[i];
                    return TrackTile(
                      track: track,
                      isCurrent: current?.id == track.id,
                      isPlaying: widget.controller.isPlaying,
                      isFavorite: widget.controller.isFavorite(track.id),
                      accentColor: accent,
                      onTap: () =>
                          widget.controller.playTrack(track, queue: _tracks),
                      onFavoriteTap: () =>
                          widget.controller.toggleFavorite(track),
                      onAddToPlaylist: () => showAddToPlaylistSheet(
                        context,
                        controller: widget.controller,
                        track: track,
                        accentColor: accent,
                      ),
                    );
                  },
                ),
              ),
            ] else
              const SliverToBoxAdapter(child: SizedBox(height: 175)),
          ],
        ],
      ),
    );
  }
}
