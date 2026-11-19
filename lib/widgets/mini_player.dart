import 'package:material_ui/material_ui.dart';
import '../services/player_controller.dart';
import 'glass.dart';

class MiniPlayer extends StatelessWidget {
  final PlayerController controller;
  final Color accentColor;
  final bool highGlass;
  final VoidCallback onTap;

  const MiniPlayer({
    super.key,
    required this.controller,
    required this.accentColor,
    required this.highGlass,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final track = controller.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -160) onTap();
      },
      child: SpringTap(
        pressedScale: 0.97,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GlassSurface(
            borderRadius: 24,
            blur: 22,
            opacity: 0.17,
            tintColor: const Color(0xFF1A1A26),
            isLens: true,
            highQuality: highGlass,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'now_playing_artwork_${track.id}',
                        child: ArtworkImage(
                          url: track.artworkUrl,
                          size: 44,
                          radius: 11,
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
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              controller.isLoadingStream
                                  ? 'Đang tải luồng âm thanh...'
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
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              controller.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(controller.isPlaying),
                              color: Colors.white,
                              size: 28,
                            ),
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
                // Isolated RepaintBoundary so 200ms progress ticks never repaint glass blur.
                RepaintBoundary(
                  child: StreamBuilder<Duration>(
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
                        minHeight: 2.2,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
