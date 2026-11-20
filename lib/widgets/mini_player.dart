import 'package:material_ui/material_ui.dart';
import '../services/player_controller.dart';
import 'glass.dart';

/// BitChord / Mochy sleek smoked floating Mini Player capsule.
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
        pressedScale: 0.98,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: GlassSurface(
            borderRadius: 22,
            blur: 24,
            isLens: true,
            highQuality: highGlass,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 6, 8),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'now_playing_artwork_${track.id}',
                        flightShuttleBuilder: (
                          _,
                          animation,
                          _,
                          _,
                          toHeroContext,
                        ) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(
                              10 + 14 * animation.value,
                            ),
                            child: toHeroContext.widget,
                          );
                        },
                        child: ArtworkImage(
                          url: track.artworkUrl,
                          size: 42,
                          radius: 10,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          layoutBuilder: (cur, prev) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...prev, ?cur],
                          ),
                          child: Column(
                            key: ValueKey(track.id),
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
                              const SizedBox(height: 1.5),
                              Text(
                                controller.isLoadingStream
                                    ? 'Đang kết nối...'
                                    : track.artist,
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
                      ),
                      if (controller.isLoadingStream || controller.isBuffering)
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
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
                            duration: const Duration(milliseconds: 160),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              controller.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(controller.isPlaying),
                              color: Colors.white,
                              size: 27,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      IconButton(
                        onPressed: () => controller.next(),
                        icon: const Icon(
                          Icons.fast_forward_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(22),
                    ),
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
                          minHeight: 1.8,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(accentColor),
                        );
                      },
                    ),
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
