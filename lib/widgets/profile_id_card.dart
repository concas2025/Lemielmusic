import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import '../models/user_profile.dart';

/// Mochy-Music inspired 1.89:1 Personal Member ID Card.
/// Supports Obsidian Dark Glass & Liquid Silver Chrome finishes with
/// interactive touch sheen and ambient micro-shimmer.
class ProfileIdCard extends StatefulWidget {
  final UserProfile profile;
  final Color accentColor;
  final int favoritesCount;
  final VoidCallback? onEditTap;
  final VoidCallback? onToggleFinish;

  const ProfileIdCard({
    super.key,
    required this.profile,
    required this.accentColor,
    required this.favoritesCount,
    this.onEditTap,
    this.onToggleFinish,
  });

  @override
  State<ProfileIdCard> createState() => _ProfileIdCardState();
}

class _ProfileIdCardState extends State<ProfileIdCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  Offset _tilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final silver = widget.profile.silverCard;
    final fg = silver ? const Color(0xFF14151D) : Colors.white;
    final fgMuted = silver
        ? const Color(0xFF14151D).withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.62);

    return GestureDetector(
      onPanUpdate: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final nx = ((d.localPosition.dx / box.size.width) - 0.5).clamp(-0.5, 0.5);
        final ny = ((d.localPosition.dy / box.size.height) - 0.5).clamp(-0.5, 0.5);
        setState(() => _tilt = Offset(nx, ny));
      },
      onPanEnd: (_) => setState(() => _tilt = Offset.zero),
      onPanCancel: () => setState(() => _tilt = Offset.zero),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(-_tilt.dy * 0.16)
          ..rotateY(_tilt.dx * 0.16),
        transformAlignment: Alignment.center,
        child: AspectRatio(
          aspectRatio: 1.89,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (silver ? Colors.white : widget.accentColor)
                      .withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (_, child) => Stack(
                  fit: StackFit.expand,
                  children: [
                    // Base metallic / obsidian gradient
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: silver
                              ? const [
                                  Color(0xFFF3F6FA),
                                  Color(0xFFD2DAE6),
                                  Color(0xFFE9EEF5),
                                  Color(0xFFB7C2D2),
                                ]
                              : [
                                  const Color(0xFF191926),
                                  const Color(0xFF0E0F17),
                                  Color.lerp(
                                    const Color(0xFF151622),
                                    widget.accentColor,
                                    0.18,
                                  )!,
                                ],
                        ),
                      ),
                    ),
                    // Interactive holographic sheen & subtle grid
                    CustomPaint(
                      painter: _IdCardSheenPainter(
                        progress: _shimmerCtrl.value,
                        tilt: _tilt,
                        silver: silver,
                        accentColor: widget.accentColor,
                      ),
                    ),
                    child!,
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Brand Emblem + Finish Toggle
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: fg.withValues(alpha: 0.10),
                              border: Border.all(
                                color: fg.withValues(alpha: 0.16),
                                width: 0.7,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 13,
                                  color: silver
                                      ? const Color(0xFF14151D)
                                      : widget.accentColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'LEMIEL PASS',
                                  style: TextStyle(
                                    color: fg,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (widget.onToggleFinish != null)
                            GestureDetector(
                              onTap: widget.onToggleFinish,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: fg.withValues(alpha: 0.08),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      silver
                                          ? Icons.dark_mode_rounded
                                          : Icons.auto_awesome_rounded,
                                      size: 13,
                                      color: fg,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      silver ? 'Obsidian' : 'Silver',
                                      style: TextStyle(
                                        color: fg,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),

                      const Spacer(),

                      // Middle row: Avatar + Name & Bio
                      Row(
                        children: [
                          ProfileAvatar(
                            profile: widget.profile,
                            accentColor: widget.accentColor,
                            size: 56,
                            borderColor: fg.withValues(alpha: 0.32),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.profile.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: fg,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ),
                                    if (widget.onEditTap != null) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: widget.onEditTap,
                                        child: Icon(
                                          Icons.edit_rounded,
                                          size: 15,
                                          color: fgMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.profile.bio,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: fgMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Bottom row: Member ID, Joined Date, Quick Plays badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MEMBER ID',
                                style: TextStyle(
                                  color: fgMuted,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                widget.profile.memberId,
                                style: TextStyle(
                                  color: fg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'SINCE ${widget.profile.joinedDate}',
                                style: TextStyle(
                                  color: fgMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${widget.profile.totalPlays} lượt nghe • ${widget.favoritesCount} ♥',
                                style: TextStyle(
                                  color: fg,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdCardSheenPainter extends CustomPainter {
  final double progress;
  final Offset tilt;
  final bool silver;
  final Color accentColor;

  _IdCardSheenPainter({
    required this.progress,
    required this.tilt,
    required this.silver,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Subtle decorative orbital arcs
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = (silver ? Colors.black : Colors.white).withValues(alpha: 0.06);
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.22),
      size.height * 0.55,
      arcPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.22),
      size.height * 0.78,
      arcPaint,
    );

    // Sweeping specular sheen reacting to time + touch tilt
    final sweep = (math.sin(progress * 2 * math.pi) * 0.35) + tilt.dx;
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1.2 + sweep, -1.0 + tilt.dy),
        end: Alignment(0.4 + sweep, 1.0 + tilt.dy),
        stops: const [0.0, 0.45, 0.55, 1.0],
        colors: [
          Colors.transparent,
          (silver ? Colors.white : accentColor).withValues(
            alpha: silver ? 0.36 : 0.14,
          ),
          Colors.white.withValues(alpha: silver ? 0.45 : 0.12),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, sheenPaint);

    // Specular outer rim
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      const Radius.circular(24),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: silver ? 0.85 : 0.40),
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: silver ? 0.55 : 0.24),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _IdCardSheenPainter old) =>
      old.progress != progress ||
      old.tilt != tilt ||
      old.silver != silver ||
      old.accentColor != accentColor;
}

/// Renders either the user's saved photo avatar or a sleek Liquid Gradient monogram.
class ProfileAvatar extends StatelessWidget {
  final UserProfile profile;
  final Color accentColor;
  final double size;
  final Color? borderColor;

  const ProfileAvatar({
    super.key,
    required this.profile,
    required this.accentColor,
    this.size = 44,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final path = profile.avatarPath;
    final hasFile = !kIsWeb && path != null && path.isNotEmpty && File(path).existsSync();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.28),
          width: 1.4,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor,
            Color.lerp(accentColor, const Color(0xFF5E5CE6), 0.55)!,
          ],
        ),
      ),
      child: ClipOval(
        child: hasFile
            ? Image.file(
                File(path),
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : Center(
                child: Text(
                  profile.initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }
}
