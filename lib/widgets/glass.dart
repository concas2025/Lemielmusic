import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../models/app_settings.dart';
import '../models/track.dart';
import '../theme/lemiel_theme.dart';

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

/// BitChord / iOS 26 smoked Liquid Glass & Mochy tonal surface.
/// - `isLens: true` (Dock, Search Orb, Mini Player, floating controls): authentic
///   smoked Liquid Glass with curved Fresnel edge specular highlight + backdrop
///   vibrancy in Liquid Glass mode, or crisp matte surface in Classic mode.
/// - `isLens: false` (content cards): clean, restrained, borderless tonal dark
///   surface (matching BitChord & Mochy's uncluttered aesthetic).
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
    this.blur = 22,
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
    final theme = LemielTheme.of(context);
    final isSemanticTint = tintColor != null &&
        tintColor != Colors.white &&
        tintColor != const Color(0xFF1A1A26) &&
        tintColor != const Color(0xFF14141E) &&
        tintColor != const Color(0xFF14141D) &&
        tintColor != const Color(0xFF18181C);

    // Classic mode OR non-lens content cards: clean borderless Mochy/BitChord tonal cards.
    if (theme.isClassic || !isLens) {
      final baseSurface = isLens ? theme.surfaceElevated : theme.surface;
      final bg = isSemanticTint
          ? Color.alphaBlend(
              tintColor!.withValues(alpha: (opacity + 0.12).clamp(0.14, 0.85)),
              baseSurface,
            )
          : baseSurface;

      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border ??
              (isLens
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                      width: 0.8,
                    )
                  : null),
          boxShadow: boxShadow ??
              (isLens
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.48),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      );
    }

    // Liquid Glass Lens mode (Dock, Search Orb, Mini Player, floating sheets):
    // Smoked dark iOS 26 / BitChord glass with vibrant refraction & razor-thin Fresnel rim.
    final useHigh = highQuality && theme.highGlass;
    final effectiveBlur = useHigh ? blur : (blur * 0.45).clamp(6.0, 12.0);

    final filter = useHigh
        ? ImageFilter.compose(
            outer: ColorFilter.matrix(_saturationMatrix(1.62)),
            inner: ImageFilter.blur(
              sigmaX: effectiveBlur,
              sigmaY: effectiveBlur,
            ),
          )
        : ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur);

    final glassFill = isSemanticTint
        ? tintColor!.withValues(alpha: (opacity + 0.16).clamp(0.20, 0.80))
        : const Color(0xFF1A1A1E).withValues(alpha: 0.68);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: filter,
          child: CustomPaint(
            foregroundPainter: border == null
                ? _LiquidLensRimPainter(borderRadius: borderRadius)
                : null,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                color: glassFill,
                border: border,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints an authentic iOS 26 / BitChord curved Fresnel edge highlight + subtle
/// top optical meniscus reflection (thin & refined, never chunky).
class _LiquidLensRimPainter extends CustomPainter {
  final double borderRadius;

  _LiquidLensRimPainter({required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.45),
      Radius.circular(borderRadius),
    );

    // Subtle upper optical meniscus highlight
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.22, 1.0],
          colors: [
            Colors.white.withValues(alpha: 0.13),
            Colors.white.withValues(alpha: 0.015),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // Razor-thin angled Fresnel specular rim
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.32, 0.68, 1.0],
          colors: [
            Colors.white.withValues(alpha: 0.36),
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.22),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidLensRimPainter old) =>
      old.borderRadius != borderRadius;
}

/// Mochy-style dotted charcoal header container (rounded bottom corners +
/// subtle micro-dot grid + optional giant background letter watermark).
class DottedHeaderSurface extends StatelessWidget {
  final Widget child;
  final String? watermarkLetter;
  final double bottomRadius;

  const DottedHeaderSurface({
    super.key,
    required this.child,
    this.watermarkLetter,
    this.bottomRadius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
      child: Container(
        color: const Color(0xFF141416),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _DotGridPainter()),
            ),
            if (watermarkLetter != null && watermarkLetter!.isNotEmpty)
              Positioned(
                right: -18,
                top: 10,
                child: IgnorePointer(
                  child: Text(
                    watermarkLetter!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.045),
                      fontSize: 220,
                      fontWeight: FontWeight.w900,
                      height: 0.9,
                    ),
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    const step = 14.0;
    for (double y = 8; y < size.height; y += step) {
      for (double x = 8; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Real physics spring-scale tactile feedback wrapper.
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
    this.pressedScale = 0.96,
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
    const spring = SpringDescription(
      mass: 1.0,
      stiffness: 520,
      damping: 26,
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
          scale: _ctrl.value.clamp(0.88, 1.04),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Short, purposeful staggered entry animation.
class StaggeredFadeSlide extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delayStep;

  const StaggeredFadeSlide({
    super.key,
    required this.child,
    this.index = 0,
    this.delayStep = const Duration(milliseconds: 24),
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
      duration: const Duration(milliseconds: 260),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delayMs = (widget.index.clamp(0, 6)) * widget.delayStep.inMilliseconds;
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

/// Clean OLED Obsidian background:
/// - Default (`enableArtworkBackdrop: false`): pure pitch-black #000000 like
///   BitChord & Mochy Music (zero garish neon blobs behind Home/Search/Library!).
/// - On Now Playing (`enableArtworkBackdrop: true`): smoothly tinted by the
///   real dominant color extracted from the current song's album cover.
class AmbientBackground extends StatelessWidget {
  final String? artworkUrl;
  final Color accentColor;
  final Color? dynamicTint;
  final PlayerBackgroundStyle style;
  final bool enableArtworkBackdrop;
  final Widget child;

  const AmbientBackground({
    super.key,
    this.artworkUrl,
    this.accentColor = Colors.white,
    this.dynamicTint,
    this.style = PlayerBackgroundStyle.ambientGlow,
    this.enableArtworkBackdrop = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = LemielTheme.of(context);
    final isOled = style == PlayerBackgroundStyle.oledBlack;

    if (!enableArtworkBackdrop || isOled) {
      return ColoredBox(color: theme.canvas, child: child);
    }

    final baseTint = dynamicTint ?? const Color(0xFF141418);
    final isAppleBlur = style == PlayerBackgroundStyle.appleBlur;
    final isDarkGrad = style == PlayerBackgroundStyle.darkGradient;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 550),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      baseTint,
                      Color.lerp(baseTint, Colors.black, 0.55)!,
                      const Color(0xFF0A0A0D),
                    ],
                  ),
                ),
              ),
              if (!theme.isClassic &&
                  !isDarkGrad &&
                  artworkUrl != null &&
                  artworkUrl!.isNotEmpty)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 650),
                  child: Opacity(
                    key: ValueKey('${artworkUrl}_${style.name}'),
                    opacity: isAppleBlur ? 0.44 : 0.22,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: isAppleBlur ? 44 : 56,
                        sigmaY: isAppleBlur ? 44 : 56,
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
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.16),
                      baseTint.withValues(alpha: 0.65),
                      const Color(0xFF0A0A0D).withValues(alpha: 0.94),
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
    this.size = 50,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final cachePx = (size * 2.2).round().clamp(120, 720);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFF1C1C20),
        child: url.isEmpty
            ? Icon(
                Icons.music_note_rounded,
                color: Colors.white.withValues(alpha: 0.35),
                size: size * 0.42,
              )
            : Image.network(
                url,
                width: size,
                height: size,
                cacheWidth: cachePx,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.music_note_rounded,
                  color: Colors.white.withValues(alpha: 0.35),
                  size: size * 0.42,
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
    this.size = 18,
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

/// BitChord / Apple Music clean borderless track row with subtle hairline divider.
class TrackTile extends StatelessWidget {
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool isFavorite;
  final Color accentColor;
  final bool showDivider;
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
    this.accentColor = Colors.white,
    this.showDivider = true,
    required this.onTap,
    this.onFavoriteTap,
    this.onAddQueue,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      pressedScale: 0.985,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: isCurrent
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.08),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ArtworkImage(url: track.artworkUrl, size: 50, radius: 9),
                    if (isCurrent)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: Colors.black.withValues(alpha: 0.52),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedEqBars(
                          isPlaying: isPlaying,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 13),
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
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.formattedDuration.isNotEmpty
                            ? '${track.artist}  ·  ${track.formattedDuration}'
                            : track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
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
                          ? Colors.white
                          : const Color(0xFF636366),
                      size: 19,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (onAddToPlaylist != null)
                  IconButton(
                    onPressed: onAddToPlaylist,
                    tooltip: 'Thêm vào Playlist',
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Color(0xFF8E8E93),
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                  )
                else if (onAddQueue != null)
                  IconButton(
                    onPressed: onAddQueue,
                    tooltip: 'Thêm vào hàng đợi',
                    icon: const Icon(
                      Icons.queue_play_next_rounded,
                      color: Color(0xFF8E8E93),
                      size: 19,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (showDivider && !isCurrent)
              Padding(
                padding: const EdgeInsets.only(left: 63, top: 8),
                child: Container(height: 0.5, color: const Color(0xFF1E1E22)),
              ),
          ],
        ),
      ),
    );
  }
}
