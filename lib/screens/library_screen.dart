import 'package:material_ui/material_ui.dart';
import '../models/track.dart';
import '../services/import_service.dart';
import '../services/player_controller.dart';
import '../services/settings_controller.dart';
import '../widgets/glass.dart';

class LibraryScreen extends StatefulWidget {
  final PlayerController controller;
  final SettingsController settingsController;
  final ImportService importService;

  const LibraryScreen({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.importService,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _tab = 0; // 0 = Playlists, 1 = Favorites, 2 = History

  @override
  Widget build(BuildContext context) {
    final settings = widget.settingsController.settings;
    final accent = settings.accentColor;
    final onAccent = settings.onAccentColor;
    final current = widget.controller.currentTrack;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Thư viện',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                  ),
                ),
              ),
              SpringTap(
                onTap: () => showImportPlaylistSheet(
                  context,
                  controller: widget.controller,
                  importService: widget.importService,
                  accentColor: accent,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: accent,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, size: 16, color: onAccent),
                      const SizedBox(width: 5),
                      Text(
                        'Nhập nhạc',
                        style: TextStyle(
                          color: onAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SpringTap(
                onTap: () => _showCreatePlaylistDialog(context, accent, onAccent),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1C1C1E),
                  ),
                  child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        // Liquid Glass 3-segment switcher
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassSurface(
            borderRadius: 18,
            opacity: 0.10,
            highQuality: settings.highGlass,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildSegment('Playlist (${widget.controller.playlists.length})', 0, accent),
                _buildSegment('Yêu thích (${widget.controller.favorites.length})', 1, accent),
                _buildSegment('Lịch sử', 2, accent),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_tab) {
              0 => _buildPlaylistsTab(accent, settings.highGlass),
              1 => _buildTrackListTab(
                  widget.controller.favorites,
                  current,
                  accent,
                  emptyMsg:
                      'Chưa có bài hát yêu thích.\nChạm biểu tượng trái tim để lưu bài hát.',
                ),
              _ => _buildTrackListTab(
                  widget.controller.history,
                  current,
                  accent,
                  emptyMsg: 'Bạn chưa nghe bài hát nào.',
                ),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab(Color accent, bool highGlass) {
    final playlists = widget.controller.playlists;

    return ListView(
      key: const ValueKey('playlists_tab'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 170),
      children: [
        // Mochy-style Multi-Platform Importer Banner
        SpringTap(
          onTap: () => showImportPlaylistSheet(
            context,
            controller: widget.controller,
            importService: widget.importService,
            accentColor: accent,
          ),
          child: GlassSurface(
            borderRadius: 22,
            opacity: 0.13,
            tintColor: accent,
            highQuality: highGlass,
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF26262B),
                  ),
                  child: const Icon(
                    Icons.cloud_download_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nhập Playlist từ nền tảng khác',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Hỗ trợ Spotify • Apple Music • YouTube Music',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 42),
            child: Text(
              'Chưa có playlist nào.\nNhấn "+" để tạo mới hoặc "Nhập nhạc" để chuyển playlist từ Spotify, Apple Music, YouTube Music.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          )
        else
          ...playlists.map((pl) {
            final coverUrl = pl.tracks.isNotEmpty ? pl.tracks.first.artworkUrl : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SpringTap(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _PlaylistDetailScreen(
                      playlistId: pl.id,
                      controller: widget.controller,
                      settingsController: widget.settingsController,
                    ),
                  ),
                ),
                child: GlassSurface(
                  borderRadius: 20,
                  opacity: 0.09,
                  highQuality: highGlass,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ArtworkImage(url: coverUrl, size: 58, radius: 14),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pl.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: accent.withValues(alpha: 0.22),
                                  ),
                                  child: Text(
                                    pl.platformLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${pl.tracks.length} bài hát',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.58),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (pl.tracks.isNotEmpty)
                        IconButton(
                          onPressed: () => widget.controller
                              .playTrack(pl.tracks.first, queue: pl.tracks),
                          icon: Icon(
                            Icons.play_circle_fill_rounded,
                            color: accent,
                            size: 32,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTrackListTab(
    List<Track> tracks,
    Track? current,
    Color accent, {
    required String emptyMsg,
  }) {
    if (tracks.isEmpty) {
      return Center(
        key: ValueKey('empty_$_tab'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            emptyMsg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return Column(
      key: ValueKey('tracks_$_tab'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Text(
                '${tracks.length} bài hát',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SpringTap(
                onTap: () => widget.controller.playTrack(tracks.first, queue: tracks),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 16,
                        color: accent.computeLuminance() > 0.55
                            ? Colors.black
                            : Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Phát tất cả',
                        style: TextStyle(
                          color: accent.computeLuminance() > 0.55
                              ? Colors.black
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 170),
            itemCount: tracks.length,
            itemBuilder: (_, i) {
              final track = tracks[i];
              return TrackTile(
                track: track,
                isCurrent: current?.id == track.id,
                isPlaying: widget.controller.isPlaying,
                isFavorite: widget.controller.isFavorite(track.id),
                accentColor: accent,
                onTap: () => widget.controller.playTrack(track, queue: tracks),
                onFavoriteTap: () => widget.controller.toggleFavorite(track),
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
      ],
    );
  }

  Widget _buildSegment(String label, int index, Color accent) {
    final active = _tab == index;
    final onAccent = accent.computeLuminance() > 0.55 ? Colors.black : Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: active ? accent : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? onAccent : const Color(0xFF8E8E93),
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(
    BuildContext context,
    Color accent,
    Color onAccent,
  ) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: GlassSurface(
          borderRadius: 28,
          blur: 26,
          opacity: 0.22,
          tintColor: const Color(0xFF14141E),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tạo Playlist mới',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'VD: Chill đêm khuya, Nhạc chạy bộ...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SpringTap(
                onTap: () async {
                  await widget.controller.createPlaylist(ctrl.text);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: accent,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Tạo Playlist',
                    style: TextStyle(
                      color: onAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final PlayerController controller;
  final SettingsController settingsController;

  const _PlaylistDetailScreen({
    required this.playlistId,
    required this.controller,
    required this.settingsController,
  });

  @override
  State<_PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<_PlaylistDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settingsController.settings;
    final accent = settings.accentColor;
    final matches =
        widget.controller.playlists.where((p) => p.id == widget.playlistId);
    if (matches.isEmpty) {
      return const Scaffold(backgroundColor: Color(0xFF06060A));
    }
    final pl = matches.first;
    final current = widget.controller.currentTrack;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AmbientBackground(
        artworkUrl: pl.tracks.isNotEmpty ? pl.tracks.first.artworkUrl : null,
        accentColor: accent,
        style: settings.backgroundStyle,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pl.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${pl.platformLabel} • ${pl.tracks.length} bài hát',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Xóa playlist',
                      onPressed: () async {
                        await widget.controller.deletePlaylist(pl.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              if (pl.tracks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SpringTap(
                    onTap: () => widget.controller
                        .playTrack(pl.tracks.first, queue: pl.tracks),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: accent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: settings.onAccentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Phát toàn bộ Playlist',
                            style: TextStyle(
                              color: settings.onAccentColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: pl.tracks.isEmpty
                    ? const Center(
                        child: Text(
                          'Playlist chưa có bài hát nào.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
                        itemCount: pl.tracks.length,
                        itemBuilder: (_, i) {
                          final track = pl.tracks[i];
                          return Dismissible(
                            key: ValueKey('${pl.id}_${track.id}'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => widget.controller
                                .removeTrackFromPlaylist(pl.id, track.id),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.redAccent.withValues(alpha: 0.4),
                              child: const Icon(
                                Icons.delete_rounded,
                                color: Colors.white,
                              ),
                            ),
                            child: TrackTile(
                              track: track,
                              isCurrent: current?.id == track.id,
                              isPlaying: widget.controller.isPlaying,
                              isFavorite: widget.controller.isFavorite(track.id),
                              accentColor: accent,
                              onTap: () => widget.controller
                                  .playTrack(track, queue: pl.tracks),
                              onFavoriteTap: () =>
                                  widget.controller.toggleFavorite(track),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mochy-style Multi-Platform Playlist Importer Sheet (Spotify / Apple Music / YouTube Music).
Future<void> showImportPlaylistSheet(
  BuildContext context, {
  required PlayerController controller,
  required ImportService importService,
  required Color accentColor,
}) async {
  final urlCtrl = TextEditingController();
  bool importing = false;
  ImportProgress? progress;
  String? error;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final detected = ImportService.detectPlatform(urlCtrl.text);

        Future<void> runImport() async {
          if (importing) return;
          setModalState(() {
            importing = true;
            error = null;
            progress = const ImportProgress(
              stage: 'Đang kết nối...',
              current: 0,
              total: 1,
            );
          });
          try {
            final playlist = await importService.importFromUrl(
              urlCtrl.text,
              onProgress: (p) {
                if (ctx.mounted) setModalState(() => progress = p);
              },
            );
            await controller.addPlaylist(playlist);
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã nhập "${playlist.name}" (${playlist.tracks.length} bài hát)!',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (ctx.mounted) {
              setModalState(() {
                importing = false;
                error = e.toString().replaceFirst('Exception: ', '');
              });
            }
          }
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: GlassSurface(
            borderRadius: 30,
            blur: 28,
            opacity: 0.22,
            tintColor: const Color(0xFF14141E),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Nhập Playlist từ nền tảng khác',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _PlatformBadge(
                      label: 'Spotify',
                      color: const Color(0xFF1DB954),
                      active: detected == 'spotify',
                    ),
                    _PlatformBadge(
                      label: 'Apple Music',
                      color: const Color(0xFFFA2D48),
                      active: detected == 'apple_music',
                    ),
                    _PlatformBadge(
                      label: 'YouTube Music',
                      color: const Color(0xFFFF0033),
                      active: detected == 'youtube_music',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlCtrl,
                  enabled: !importing,
                  onChanged: (_) => setModalState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText:
                        'Dán link playlist công khai (open.spotify.com, music.apple.com, music.youtube.com)...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (importing && progress != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress!.total > 1 ? progress!.fraction : null,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    progress!.stage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFFFF7A70),
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SpringTap(
                  onTap: importing ? null : runImport,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: importing
                          ? accentColor.withValues(alpha: 0.45)
                          : accentColor,
                    ),
                    alignment: Alignment.center,
                      child: Text(
                        importing ? 'Đang nhập playlist...' : 'Bắt đầu nhập ngay',
                        style: TextStyle(
                          color: accentColor.computeLuminance() > 0.55
                              ? Colors.black
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _PlatformBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  const _PlatformBadge({
    required this.label,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active ? color.withValues(alpha: 0.30) : color.withValues(alpha: 0.12),
        border: Border.all(
          color: active ? color : color.withValues(alpha: 0.35),
          width: active ? 1.4 : 0.8,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Reusable Bottom Sheet to add any track to a local playlist or queue.
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required PlayerController controller,
  required Track track,
  required Color accentColor,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final playlists = controller.playlists;
      return GlassSurface(
        borderRadius: 28,
        blur: 26,
        opacity: 0.22,
        tintColor: const Color(0xFF14141E),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.queue_play_next_rounded, color: accentColor),
              title: const Text(
                'Thêm vào hàng đợi phát tiếp',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                controller.addToQueue(track);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã thêm "${track.title}" vào hàng đợi'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            if (playlists.isNotEmpty) ...[
              const Divider(color: Colors.white12),
              const Text(
                'Thêm vào Playlist của bạn',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              ...playlists.take(5).map(
                    (pl) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.playlist_add_rounded,
                        color: Colors.white70,
                      ),
                      title: Text(
                        pl.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${pl.tracks.length} bài hát',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      onTap: () async {
                        await controller.addTrackToPlaylist(pl.id, track);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã thêm vào "${pl.name}"'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
            ],
          ],
        ),
      );
    },
  );
}
