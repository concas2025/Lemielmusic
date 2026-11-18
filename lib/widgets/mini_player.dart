import 'package:material_ui/material_ui.dart';
import '../services/player_controller.dart';
import 'glass.dart';

class MiniPlayer extends StatelessWidget {
  final PlayerController controller;
  final VoidCallback onTap;

  const MiniPlayer({
    super.key,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final track = controller.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -180) onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: GlassSurface(
          borderRadius: 20,
          blur: 30,
          opacity: 0.14,
          tintColor: const Color(0xFF1F1F29),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Hero(
                      tag: 'now_playing_artwork_${track.id}',
                      child: ArtworkImage(
                        url: track.artworkUrl,
                        size: 44,
                        radius: 10,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            controller.isLoadingStream
                                ? 'Đang kết nối âm thanh...'
                                : track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (controller.isLoadingStream || controller.isBuffering)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        onPressed: controller.togglePlayPause,
                        icon: Icon(
                          controller.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      onPressed: () => controller.next(),
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white70,
                        size: 26,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              StreamBuilder<Duration>(
                stream: controller.positionStream,
                initialData: controller.currentPosition,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final total = controller.duration.inMilliseconds;
                  final progress = total > 0
                      ? (pos.inMilliseconds / total).clamp(0.0, 1.0)
                      : 0.0;
                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF375F),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
