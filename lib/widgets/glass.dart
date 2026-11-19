import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../models/app_settings.dart';
import '../models/track.dart';

/// Builds a 4x5 saturation color matrix for Apple iOS 26 Liquid Glass vibrancy.
List<double> _saturationMatrix(double sat) {
  final inv = 1.0 - sat;
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  return [
    r * inv + sat, g * inv, b * inv, 0, 0,
    r * inv, g * inv + sat, b * inv, 0, 0,
    r * inv, g * inv, b * inv + sat, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? tintColor;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final Border? border;
  final bool isLens;
  final bool highQuality;
  final List<BoxShadow>? boxShadow;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.blur = 18,
    this.tintColor,
    this.opacity = 0.10,
    this.padding,
    this.border,
    this.isLens = false,
    this.highQuality = true,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final base = tintColor ?? Colors.white;
    final effectiveBlur = highQuality ? blur : (blur * 0.45).clamp(4.0, 10.0);

    final filter = highQuality
        ? ImageFilter.compose(
            outer: ColorFilter.matrix(_saturationMatrix(isLens ? 1.65 : 1.38)),
            inner: ImageFilter.blur(
              sigmaX: effectiveBlur,
              sigmaY: effectiveBlur,
            ),
          )
        : ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur);

    final surface = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: filter,
        child: CustomPaint(
          foregroundPainter: border == null
              ? _LiquidSpecularRimPainter(
                  borderRadius: borderRadius,
                  isLens: isLens,
                  tintColor: tintColor,
                )
              : null,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  base.withValues(alpha: (opacity + (isLens ? 0.11 : 0.06)).clamp(0.0, 0.95)),
                  base.withValues(alpha: (opacity * 0.65).clamp(0.0, 0.9)),
                  base.withValues(alpha: (opacity * 0.85).clamp(0.0, 0.9)),
                ],
              ),
              border: border,
            ),
            child: child,
          ),
        ),
      ),
    );

    if (boxShadow != null || isLens) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: boxShadow ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
        ),
        child: surface,
      );
    }

    return surface;
  }
}

/// Paints an angled iOS 26 Liquid Glass specular refraction rim + subtle top sheen.
class _LiquidSpecularRimPainter extends CustomPainter {
  final double borderRadius;
  final bool isLens;
  final Color? tintColor;

  _LiquidSpecularRimPainter({
    required this.borderRadius,
    required this.isLens,
    this.tintColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.6),
      Radius.circular(borderRadius),
    );

    // Subtle upper specular highlight inside the glass edge.
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.28, 1.0],
        colors: [
          Colors.white.withValues(alpha: isLens ? 0.22 : 0.11),
          Colors.white.withValues(alpha: 0.01),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, sheenPaint);

    // Angled specular rim border (bright top-left & softer bottom-right refraction).
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isLens ? 1.15 : 0.95
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.38, 0.68, 1.0],
        colors: [
          Colors.white.withValues(alpha: isLens ? 0.56 : 0.34),
          Colors.white.withValues(alpha: isLens ? 0.14 : 0.07),
          (tintColor ?? Colors.white).withValues(alpha: isLens ? 0.14 : 0.06),
          Colors.white.withValues(alpha: isLens ? 0.34 : 0.20),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidSpecularRimPainter old) =>
      old.borderRadius != borderRadius ||
      old.isLens != isLens ||
      old.tintColor != tintColor;
}

/// Real physics spring-scale tactile feedback button wrapper.
class SpringTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;

  const SpringTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.94,
    this.haptic = true,
  });

  @override
  State<SpringTap> createState() => _SpringTapState();
}

class _SpringTapState extends State<SpringTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this, value: 1.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final spring = const SpringDescription(
      mass: 1.0,
      stiffness: 520,
      damping: 24,
    );
    _ctrl.animateWith(SpringSimulation(spring, _ctrl.value, target, 0));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null || widget.onLongPress != null
          ? (_) => _animateTo(widget.pressedScale)
          : null,
      onTapUp: (_) => _animateTo(1.0),
      onTapCancel: () => _animateTo(1.0),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: _ctrl.value.clamp(0.85, 1.06),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Subtle staggered fade + upward slide entry animation.
class StaggeredFadeSlide extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delayStep;

  const StaggeredFadeSlide({
    super.key,
    required this.child,
    this.index = 0,
    this.delayStep = const Duration(milliseconds: 35),
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delayMs = (widget.index.clamp(0, 10)) * widget.delayStep.inMilliseconds;
    if (delayMs == 0) {
      _ctrl.forward();
    } else {
      Future<void>.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

/// GPU-optimized Ambient Background isolated inside a RepaintBoundary.
class AmbientBackground extends StatelessWidget {
  final String? artworkUrl;
  final Color accentColor;
  final PlayerBackgroundStyle style;
  final Widget child;

  const AmbientBackground({
    super.key,
    this.artworkUrl,
    this.accentColor = const Color(0xFFFF375F),
    this.style = PlayerBackgroundStyle.ambientGlow,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isOled = style == PlayerBackgroundStyle.oledBlack;
    final isDarkGrad = style == PlayerBackgroundStyle.darkGradient;
    final isAppleBlur = style == PlayerBackgroundStyle.appleBlur;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: isOled ? Colors.black : const Color(0xFF06060A)),
              if (!isOled) ...[
                Positioned(
                  top: -130,
                  left: -90,
                  child: Container(
                    width: 360,
                    height: 360,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accentColor.withValues(
                            alpha: isDarkGrad ? 0.14 : 0.25,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 150,
                  right: -110,
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF5E5CE6).withValues(
                            alpha: isDarkGrad ? 0.10 : 0.22,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (!isOled &&
                  !isDarkGrad &&
                  artworkUrl != null &&
                  artworkUrl!.isNotEmpty)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  child: Opacity(
                    key: ValueKey('${artworkUrl}_${style.name}'),
                    opacity: isAppleBlur ? 0.52 : 0.30,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: isAppleBlur ? 42 : 52,
                        sigmaY: isAppleBlur ? 42 : 52,
                      ),
                      child: Image.network(
                        artworkUrl!,
                        cacheWidth: 120,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              if (!isOled)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isAppleBlur
                          ? [
                              Colors.black.withValues(alpha: 0.18),
                              const Color(0xFF07070B).withValues(alpha: 0.56),
                              const Color(0xFF06060A).withValues(alpha: 0.88),
                            ]
                          : [
                              Colors.black.withValues(alpha: 0.24),
                              const Color(0xFF06060A).withValues(alpha: 0.72),
                              const Color(0xFF06060A).withValues(alpha: 0.95),
                            ],
                    ),
                  ),
                ),
            ],
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
    final cachePx = (size * 2.2).round().clamp(120, 720);
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
                cacheWidth: cachePx,
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

/// Live animated 3-bar music equalizer indicator for active tracks.
class AnimatedEqBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const AnimatedEqBars({
    super.key,
    required this.isPlaying,
    required this.color,
    this.size = 20,
  });

  @override
  State<AnimatedEqBars> createState() => _AnimatedEqBarsState();
}

class _AnimatedEqBarsState extends State<AnimatedEqBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedEqBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isPlaying && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value * 2 * math.pi;
        final h1 = widget.isPlaying ? 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t)) : 0.32;
        final h2 = widget.isPlaying ? 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t + 1.9)) : 0.55;
        final h3 = widget.isPlaying ? 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t + 3.8)) : 0.38;
        final barW = widget.size * 0.18;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [h1, h2, h3].map((f) {
              return Container(
                width: barW,
                height: (widget.size * f).clamp(4.0, widget.size),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(barW),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class TrackTile extends StatelessWidget {
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool isFavorite;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onAddQueue;
  final VoidCallback? onAddToPlaylist;

  const TrackTile({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.isFavorite,
    this.accentColor = const Color(0xFFFF375F),
    required this.onTap,
    this.onFavoriteTap,
    this.onAddQueue,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      pressedScale: 0.975,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: isCurrent
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: accentColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.38),
                  width: 0.9,
                ),
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.transparent,
              ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ArtworkImage(url: track.artworkUrl, size: 52, radius: 13),
                if (isCurrent)
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: Colors.black.withValues(alpha: 0.50),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedEqBars(
                      isPlaying: isPlaying,
                      color: accentColor,
                      size: 20,
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
                      color: isCurrent ? accentColor : Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 12.5,
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
                      ? accentColor
                      : Colors.white.withValues(alpha: 0.45),
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
            if (onAddToPlaylist != null)
              IconButton(
                onPressed: onAddToPlaylist,
                tooltip: 'Thêm vào Playlist',
                icon: Icon(
                  Icons.playlist_add_rounded,
                  color: Colors.white.withValues(alpha: 0.48),
                  size: 21,
                ),
                visualDensity: VisualDensity.compact,
              )
            else if (onAddQueue != null)
              IconButton(
                onPressed: onAddQueue,
                tooltip: 'Thêm vào hàng đợi',
                icon: Icon(
                  Icons.queue_play_next_rounded,
                  color: Colors.white.withValues(alpha: 0.48),
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
