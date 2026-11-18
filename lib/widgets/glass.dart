import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import '../models/track.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? tintColor;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.blur = 26,
    this.tintColor,
    this.opacity = 0.08,
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final base = tintColor ?? Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                base.withValues(alpha: opacity + 0.04),
                base.withValues(alpha: opacity * 0.6),
              ],
            ),
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.13),
                  width: 0.8,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AmbientBackground extends StatelessWidget {
  final String? artworkUrl;
  final Widget child;

  const AmbientBackground({
    super.key,
    this.artworkUrl,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF07070B)),
        // Subtle ambient aurora glow
        Positioned(
          top: -120,
          left: -80,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFF375F).withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 140,
          right: -100,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF5E5CE6).withValues(alpha: 0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        if (artworkUrl != null && artworkUrl!.isNotEmpty)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: Opacity(
              key: ValueKey(artworkUrl),
              opacity: 0.28,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: Image.network(
                  artworkUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.20),
                const Color(0xFF07070B).withValues(alpha: 0.72),
                const Color(0xFF07070B).withValues(alpha: 0.94),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class ArtworkImage extends StatelessWidget {
  final String url;
  final double size;
  final double radius;

  const ArtworkImage({
    super.key,
    required this.url,
    this.size = 52,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: Colors.white.withValues(alpha: 0.06),
        child: url.isEmpty
            ? Icon(
                Icons.music_note_rounded,
                color: Colors.white.withValues(alpha: 0.45),
                size: size * 0.45,
              )
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.music_note_rounded,
                  color: Colors.white.withValues(alpha: 0.45),
                  size: size * 0.45,
                ),
              ),
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onAddQueue;

  const TrackTile({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.isFavorite,
    required this.onTap,
    this.onFavoriteTap,
    this.onAddQueue,
  });

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFFF375F);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: isCurrent
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                )
              : null,
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ArtworkImage(url: track.artworkUrl, size: 52, radius: 12),
                  if (isCurrent)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.graphic_eq_rounded
                            : Icons.pause_rounded,
                        color: accent,
                        size: 24,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? accent : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.formattedDuration.isNotEmpty
                          ? '${track.artist}  •  ${track.formattedDuration}'
                          : track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (onFavoriteTap != null)
                IconButton(
                  onPressed: onFavoriteTap,
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite
                        ? accent
                        : Colors.white.withValues(alpha: 0.45),
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              if (onAddQueue != null)
                IconButton(
                  onPressed: onAddQueue,
                  tooltip: 'Thêm vào hàng đợi',
                  icon: Icon(
                    Icons.playlist_add_rounded,
                    color: Colors.white.withValues(alpha: 0.45),
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
