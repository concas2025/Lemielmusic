import 'package:material_ui/material_ui.dart';
import '../services/player_controller.dart';
import '../widgets/glass.dart';

class LibraryScreen extends StatefulWidget {
  final PlayerController controller;

  const LibraryScreen({super.key, required this.controller});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _tab = 0; // 0 = Favorites, 1 = History

  @override
  Widget build(BuildContext context) {
    final tracks =
        _tab == 0 ? widget.controller.favorites : widget.controller.history;
    final current = widget.controller.currentTrack;
    const accent = Color(0xFFFF375F);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Thư viện',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              if (tracks.isNotEmpty)
                GestureDetector(
                  onTap: () => widget.controller
                      .playTrack(tracks.first, queue: tracks),
                  child: const GlassSurface(
                    borderRadius: 20,
                    opacity: 0.25,
                    tintColor: accent,
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Phát tất cả',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassSurface(
            borderRadius: 16,
            opacity: 0.08,
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildSegment('Yêu thích (${widget.controller.favorites.length})', 0),
                _buildSegment('Lịch sử (${widget.controller.history.length})', 1),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: tracks.isEmpty
              ? Center(
                  child: Text(
                    _tab == 0
                        ? 'Chưa có bài hát yêu thích.\nNhấn biểu tượng trái tim để lưu bài hát.'
                        : 'Bạn chưa nghe bài hát nào.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 160),
                  itemCount: tracks.length,
                  itemBuilder: (_, i) {
                    final track = tracks[i];
                    return TrackTile(
                      track: track,
                      isCurrent: current?.id == track.id,
                      isPlaying: widget.controller.isPlaying,
                      isFavorite: widget.controller.isFavorite(track.id),
                      onTap: () =>
                          widget.controller.playTrack(track, queue: tracks),
                      onFavoriteTap: () =>
                          widget.controller.toggleFavorite(track),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSegment(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
