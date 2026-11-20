import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import '../models/user_profile.dart';
import '../theme/lemiel_theme.dart';

/// Personal Member ID Card faithfully modeled after the 1.89:1 brushed-metal /
/// obsidian pass layout with a 90°-rotated vertical scrolling marquee strip,
/// proportional unit scaling, interactive sheen, and 100% Lemielmusic identity.
class ProfileIdCard extends StatefulWidget {
  final UserProfile profile;
  final Color accentColor;
  final int favoritesCount;
  final bool? forceSilver;
  final bool showEditHint;
  final VoidCallback? onEditTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onToggleFinish;

  const ProfileIdCard({
    super.key,
    required this.profile,
    required this.accentColor,
    required this.favoritesCount,
    this.forceSilver,
    this.showEditHint = false,
    this.onEditTap,
    this.onAvatarTap,
    this.onToggleFinish,
  });

  @override
  State<ProfileIdCard> createState() => _ProfileIdCardState();
}

class _ProfileIdCardState extends State<ProfileIdCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionCtrl;
  Offset _tilt = Offset.zero;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _motionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _motionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = LemielTheme.of(context);
    final silver = widget.forceSilver ?? widget.profile.silverCard;
    final fg = silver ? const Color(0xFF111114) : Colors.white;
    final fgMuted = silver
        ? const Color(0xFF3A3A40)
        : const Color(0xFFB5B5BD);
    final stripBg = silver
        ? Colors.black.withValues(alpha: 0.16)
        : (theme.isClassic ? const Color(0xFF161820) : const Color(0xFF17171D));
    final stripFg = silver
        ? const Color(0xFF2B2B30).withValues(alpha: 0.78)
        : const Color(0xFF8C8C96);

    final displayName = widget.profile.displayName.trim().isNotEmpty
        ? widget.profile.displayName.trim()
        : 'Người nghe Lemiel';

    return GestureDetector(
      onPanDown: (_) => setState(() => _pressed = true),
      onPanUpdate: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final nx = ((d.localPosition.dx / box.size.width) - 0.5).clamp(-0.5, 0.5);
        final ny = ((d.localPosition.dy / box.size.height) - 0.5).clamp(-0.5, 0.5);
        setState(() => _tilt = Offset(nx, ny));
      },
      onPanEnd: (_) => setState(() {
        _tilt = Offset.zero;
        _pressed = false;
      }),
      onPanCancel: () => setState(() {
        _tilt = Offset.zero;
        _pressed = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(-_tilt.dy * 0.14)
          ..rotateY(_tilt.dx * 0.14),
        transformAlignment: Alignment.center,
        child: AspectRatio(
          aspectRatio: 1.89,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Proportional unit matching the 332x176 card blueprint
              final unit = (constraints.maxWidth / 332.0).clamp(0.75, 1.5);

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: (silver ? Colors.white : widget.accentColor)
                          .withValues(alpha: theme.isClassic ? 0.08 : 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.42),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AnimatedBuilder(
                    animation: _motionCtrl,
                    builder: (_, child) => Stack(
                      fit: StackFit.expand,
                      children: [
                        // Card material surface (Brushed Silver vs Obsidian Dark)
                        CustomPaint(
                          painter: _CardSurfacePainter(
                            silver: silver,
                            isClassic: theme.isClassic,
                            accentColor: widget.accentColor,
                            sheen: 0.5 +
                                math.sin(_motionCtrl.value * 2 * math.pi) * 0.28 +
                                _tilt.dx * 0.8,
                            pressed: _pressed,
                          ),
                        ),
                        child!,
                      ],
                    ),
                    child: Row(
                      children: [
                        // Left main ID card content
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              unit * 20,
                              unit * 16,
                              unit * 12,
                              unit * 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top monospace row: LEMIEL • MEMBER ID + Finish toggle
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'LEMIEL • ${widget.profile.memberId}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: fgMuted,
                                          fontFamily: 'monospace',
                                          fontSize: unit * 10.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                    if (widget.onToggleFinish != null)
                                      GestureDetector(
                                        onTap: widget.onToggleFinish,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: unit * 7,
                                            vertical: unit * 3,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            color: fg.withValues(alpha: 0.09),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                silver
                                                    ? Icons.dark_mode_rounded
                                                    : Icons.auto_awesome_rounded,
                                                size: unit * 11,
                                                color: fg,
                                              ),
                                              SizedBox(width: unit * 3),
                                              Text(
                                                silver ? 'Obsidian' : 'Silver',
                                                style: TextStyle(
                                                  color: fg,
                                                  fontSize: unit * 9.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const Spacer(),

                                // Main Identity Row: Large Circular Avatar + Name/Meta
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: widget.onAvatarTap ?? widget.onEditTap,
                                      child: Stack(
                                        children: [
                                          ProfileAvatar(
                                            profile: widget.profile,
                                            accentColor: widget.accentColor,
                                            size: unit * 86,
                                            borderColor: fg.withValues(alpha: 0.25),
                                            showAddPlaceholder:
                                                widget.onAvatarTap != null &&
                                                    widget.profile.avatarPath == null &&
                                                    widget.showEditHint,
                                          ),
                                          if (widget.onAvatarTap != null &&
                                              widget.showEditHint)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: unit * 24,
                                                height: unit * 24,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: silver
                                                      ? const Color(0xFF181920)
                                                      : widget.accentColor,
                                                  border: Border.all(
                                                    color: silver
                                                        ? const Color(0xFFE5E7EC)
                                                        : const Color(0xFF23252E),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.camera_alt_rounded,
                                                  size: unit * 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: unit * 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'THẺ THÀNH VIÊN',
                                            style: TextStyle(
                                              color: fgMuted,
                                              fontFamily: 'monospace',
                                              fontSize: unit * 9.2,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          SizedBox(height: unit * 2),
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  displayName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: fg,
                                                    fontSize: unit * 20,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.5,
                                                    height: 1.12,
                                                  ),
                                                ),
                                              ),
                                              if ((widget.showEditHint ||
                                                      widget.onEditTap != null) &&
                                                  widget.onEditTap != null) ...[
                                                SizedBox(width: unit * 5),
                                                GestureDetector(
                                                  onTap: widget.onEditTap,
                                                  child: Icon(
                                                    Icons.edit_rounded,
                                                    size: unit * 12.5,
                                                    color: fgMuted,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          SizedBox(height: unit * 4),
                                          Text(
                                            'Tham gia từ ${widget.profile.joinedDate}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: fg.withValues(alpha: 0.82),
                                              fontSize: unit * 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (widget.profile.totalPlays > 0 ||
                                              widget.favoritesCount > 0) ...[
                                            SizedBox(height: unit * 2),
                                            Text(
                                              '${widget.profile.totalPlays} lượt nghe • ${widget.favoritesCount} yêu thích',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: fgMuted,
                                                fontSize: unit * 9.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ] else if (widget.profile.bio.isNotEmpty) ...[
                                            SizedBox(height: unit * 2),
                                            Text(
                                              widget.profile.bio,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: fgMuted,
                                                fontSize: unit * 9.5,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(),
                              ],
                            ),
                          ),
                        ),

                        // Right Vertical Signature Marquee Strip (40*unit wide)
                        SizedBox(
                          width: unit * 38,
                          height: double.infinity,
                          child: AnimatedBuilder(
                            animation: _motionCtrl,
                            builder: (_, _) => CustomPaint(
                              painter: _VerticalMarqueePainter(
                                text: 'LEMIELMUSIC • ${displayName.toUpperCase()}   ·   ',
                                color: stripFg,
                                background: stripBg,
                                fontSize: unit * 13.5,
                                progress: _motionCtrl.value,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Paints brushed metallic silver (with 3px horizontal micro-grain + diagonal
/// specular sheen) or deep obsidian graphite/glass.
class _CardSurfacePainter extends CustomPainter {
  final bool silver;
  final bool isClassic;
  final Color accentColor;
  final double sheen;
  final bool pressed;

  _CardSurfacePainter({
    required this.silver,
    required this.isClassic,
    required this.accentColor,
    required this.sheen,
    required this.pressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (silver) {
      // 5-stop brushed silver metallic base
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.35, 0.55, 0.80, 1.0],
            colors: [
              Color(0xFFBFC1C6),
              Color(0xFFE9EAEE),
              Color(0xFFA9ABB2),
              Color(0xFFD7D9DE),
              Color(0xFF9C9EA5),
            ],
          ).createShader(rect),
      );

      // Fine horizontal brushed-metal micro-grain every 3px
      final grainEven = Paint()
        ..color = Colors.white.withValues(alpha: 0.055)
        ..strokeWidth = 1.0;
      final grainOdd = Paint()
        ..color = Colors.white.withValues(alpha: 0.025)
        ..strokeWidth = 1.0;
      final lines = (size.height / 3.0).floor();
      for (int i = 0; i < lines; i++) {
        final y = i * 3.0;
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          i.isEven ? grainEven : grainOdd,
        );
      }

      // Soft diagonal specular sheen highlight
      final cx = sheen.clamp(-0.2, 1.2) * size.width;
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = LinearGradient(
            begin: Alignment((cx - size.width * 0.35) / size.width * 2 - 1, -1),
            end: Alignment((cx + size.width * 0.15) / size.width * 2 - 1, 1),
            stops: const [0.0, 0.5, 1.0],
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.45),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
    } else {
      // Deep obsidian matte / liquid glass dark card
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isClassic
                ? const [
                    Color(0xFF262936),
                    Color(0xFF1D202B),
                    Color(0xFF232634),
                  ]
                : [
                    const Color(0xFF282834),
                    const Color(0xFF1A1B24),
                    Color.lerp(const Color(0xFF20212D), accentColor, 0.16)!,
                  ],
          ).createShader(rect),
      );

      // Subtle diagonal shimmer on dark card
      final cx = sheen.clamp(-0.2, 1.2) * size.width;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment((cx - size.width * 0.35) / size.width * 2 - 1, -1),
            end: Alignment((cx + size.width * 0.15) / size.width * 2 - 1, 1),
            stops: const [0.0, 0.5, 1.0],
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: isClassic ? 0.05 : 0.09),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
    }

    if (pressed) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: silver ? 0.22 : 0.10),
      );
    }

    // Crisp outer rim
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.6),
      const Radius.circular(22),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: silver ? 0.72 : 0.28),
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: silver ? 0.45 : 0.18),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _CardSurfacePainter old) =>
      old.silver != silver ||
      old.isClassic != isClassic ||
      old.accentColor != accentColor ||
      old.sheen != sheen ||
      old.pressed != pressed;
}

/// Draws 90°-rotated vertical continuously scrolling marquee text on the right
/// strip of the ID card with zero widget tree rebuilds.
class _VerticalMarqueePainter extends CustomPainter {
  final String text;
  final Color color;
  final Color background;
  final double fontSize;
  final double progress;

  _VerticalMarqueePainter({
    required this.text,
    required this.color,
    required this.background,
    required this.fontSize,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final step = math.max(tp.width, 1.0);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.rotate(math.pi / 2);
    final top = -size.width / 2 - tp.height / 2;

    double x = -step + (progress % 1.0) * step;
    while (x < size.height) {
      tp.paint(canvas, Offset(x, top));
      x += step;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VerticalMarqueePainter old) =>
      old.progress != progress ||
      old.text != text ||
      old.color != color ||
      old.background != background ||
      old.fontSize != fontSize;
}

/// Renders either the user's saved photo avatar or their chosen curated monogram
/// gradient (with an optional subtle `+` placeholder during onboarding).
class ProfileAvatar extends StatelessWidget {
  final UserProfile profile;
  final Color accentColor;
  final double size;
  final Color? borderColor;
  final bool showAddPlaceholder;

  const ProfileAvatar({
    super.key,
    required this.profile,
    required this.accentColor,
    this.size = 44,
    this.borderColor,
    this.showAddPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    final path = profile.avatarPath;
    final hasFile =
        !kIsWeb && path != null && path.isNotEmpty && File(path).existsSync();
    final colors = profile.avatarPresetIndex == 0
        ? [
            accentColor,
            Color.lerp(accentColor, const Color(0xFF5E5CE6), 0.55)!,
          ]
        : profile.avatarColors;

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
          colors: colors,
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
                child: showAddPlaceholder
                    ? Icon(
                        Icons.add_a_photo_rounded,
                        color: Colors.white.withValues(alpha: 0.88),
                        size: size * 0.34,
                      )
                    : Text(
                        profile.initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size * 0.36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
      ),
    );
  }
}
