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
    final settings = widget.settingsController.settings;
    final profile = widget.settingsController.profile;
    final accent = settings.accentColor;

    return RefreshIndicator(
      color: accent,
      backgroundColor: const Color(0xFF16161F),
      onRefresh: () => _loadMood(_selectedMood, force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Personalized Liquid Glass Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'XIN CHÀO, ${profile.displayName.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.90),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Lemielmusic',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SpringTap(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CustomisationScreen(
                          settingsController: widget.settingsController,
                          previewArtworkUrl: current?.artworkUrl,
                        ),
                      ),
                    ),
                    child: GlassSurface(
                      borderRadius: 18,
                      opacity: 0.12,
                      highQuality: settings.highGlass,
                      padding: const EdgeInsets.all(9),
                      child: const Icon(
                        Icons.palette_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SpringTap(
                    onTap: widget.onProfileTap,
                    child: ProfileAvatar(
                      profile: profile,
                      accentColor: accent,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Studio Pills: Audio Lab + Import Playlist
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SpringTap(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AudioLabScreen(
                            controller: widget.controller,
                            settingsController: widget.settingsController,
                          ),
                        ),
                      ),
                      child: GlassSurface(
                        borderRadius: 18,
                        opacity: 0.10,
                        highQuality: settings.highGlass,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.graphic_eq_rounded, color: accent, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Audio Lab',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SpringTap(
                      onTap: () => showImportPlaylistSheet(
                        context,
                        controller: widget.controller,
                        importService: widget.importService,
                        accentColor: accent,
                      ),
                      child: GlassSurface(
                        borderRadius: 18,
                        opacity: 0.10,
                        highQuality: settings.highGlass,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.cloud_download_rounded,
                              color: Color(0xFF6E6BF5),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nhập Playlist',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
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
          ),

          // Mood selector Liquid Glass pills
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
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
                    child: Center(
                      child: GlassSurface(
                        borderRadius: 20,
                        blur: 14,
                        opacity: active ? 0.30 : 0.08,
                        tintColor: active ? accent : Colors.white,
                        highQuality: settings.highGlass,
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 162,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: history.take(10).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final item = history[i];
                    return SpringTap(
                      onTap: () =>
                          widget.controller.playTrack(item, queue: history),
                      child: SizedBox(
                        width: 114,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ArtworkImage(
                              url: item.artworkUrl,
                              size: 114,
                              radius: 18,
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
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          if (_loading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: accent)),
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 175),
              sliver: SliverList.builder(
                itemCount: _tracks.length,
                itemBuilder: (_, i) {
                  final track = _tracks[i];
                  return StaggeredFadeSlide(
                    index: i,
                    child: TrackTile(
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
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
