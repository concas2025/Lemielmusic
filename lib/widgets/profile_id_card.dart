import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import '../models/user_profile.dart';

/// Mochy-Music exact 1.89:1 Personal Member ID Card (100% Lemielmusic brand):
/// - Matte charcoal (#2F2F2F) on Profile (clean, zero neon glow) OR brushed
///   metallic silver with 3px horizontal micro-grain & diagonal sheen on
///   Onboarding / toggle.
/// - Proportional unit scaling (`maxWidth / 332`) with monospace PROFILE USR#,
///   large circular avatar, `ID CARD OF`, bold username, joined date, and
///   continuously scrolling 90°-rotated right vertical marquee strip.
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
    final silver = widget.forceSilver ?? widget.profile.silverCard;
    final fg = silver ? const Color(0xFF111114) : Colors.white;
    final fgMuted = silver ? const Color(0xFF3A3A40) : const Color(0xFFB5B5B5);
    final stripBg = silver
        ? Colors.black.withValues(alpha: 0.18)
        : const Color(0xFF1B1B1B);
    final stripFg = silver
        ? const Color(0xFF2B2B30).withValues(alpha: 0.78)
        : const Color(0xFF8A8A8A);

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
          ..rotateX(-_tilt.dy * 0.12)
          ..rotateY(_tilt.dx * 0.12),
        transformAlignment: Alignment.center,
        child: AspectRatio(
          aspectRatio: 1.89,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final unit = (constraints.maxWidth / 332.0).clamp(0.75, 1.5);

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
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
                        CustomPaint(
                          painter: _CardSurfacePainter(
                            silver: silver,
                            sheen: 0.5 +
                                math.sin(_motionCtrl.value * 2 * math.pi) *
                                    0.28 +
                                _tilt.dx * 0.8,
                            pressed: _pressed,
                          ),
                        ),
                        child!,
                      ],
                    ),
                    child: Row(
                      children: [
                        // Left main body
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              unit * 22,
                              unit * 18,
                              unit * 12,
                              unit * 18,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top monospace row: PROFILE USR#LM-...
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'USR#${widget.profile.memberId}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: fgMuted,
                                          fontFamily: 'monospace',
                                          fontSize: unit * 10.0,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    if (widget.showEditHint &&
                                        widget.onEditTap != null) ...[
                                      SizedBox(width: unit * 5),
                                      GestureDetector(
                                        onTap: widget.onEditTap,
                                        child: Icon(
                                          Icons.edit_outlined,
                                          size: unit * 11,
                                          color: fgMuted,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (widget.onToggleFinish != null)
                                      GestureDetector(
                                        onTap: widget.onToggleFinish,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: unit * 7,
                                            vertical: unit * 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            color: fg.withValues(alpha: 0.08),
                                          ),
                                          child: Text(
                                            silver ? 'Dark' : 'Silver',
                                            style: TextStyle(
                                              color: fgMuted,
                                              fontSize: unit * 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const Spacer(),

                                // Center Identity Row: 92*unit Circle Avatar + Name/Joined
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: widget.onAvatarTap ??
                                          widget.onEditTap,
                                      child: ProfileAvatar(
                                        profile: widget.profile,
                                        accentColor: widget.accentColor,
                                        size: unit * 92,
                                        neutralMonochrome: true,
                                        showAddPlaceholder:
                                            widget.onAvatarTap != null &&
                                                widget.profile.avatarPath ==
                                                    null &&
                                                widget.showEditHint,
                                      ),
                                    ),
                                    SizedBox(width: unit * 18),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'ID CARD OF',
                                            style: TextStyle(
                                              color: fgMuted,
                                              fontFamily: 'monospace',
                                              fontSize: unit * 9.5,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          SizedBox(height: unit * 2),
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  displayName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: fg,
                                                    fontSize: unit * 21,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.5,
                                                    height: 1.15,
                                                  ),
                                                ),
                                              ),
                                              if (widget.showEditHint &&
                                                  widget.onEditTap != null) ...[
                                                SizedBox(width: unit * 5),
                                                GestureDetector(
                                                  onTap: widget.onEditTap,
                                                  child: Icon(
                                                    Icons.edit_outlined,
                                                    size: unit * 12,
                                                    color: fgMuted,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          SizedBox(height: unit * 4),
                                          Text(
                                            'joined ${widget.profile.joinedDate}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: fg.withValues(alpha: 0.82),
                                              fontSize: unit * 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
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
                          width: unit * 40,
                          height: double.infinity,
                          child: AnimatedBuilder(
                            animation: _motionCtrl,
                            builder: (_, _) => CustomPaint(
                              painter: _VerticalMarqueePainter(
                                text: "$displayName's CARD   ·   LEMIEL   ·   ",
                                color: stripFg,
                                background: stripBg,
                                fontSize: unit * 14.5,
                                fontFamily:
                                    DefaultTextStyle.of(context).style.fontFamily,
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

class _CardSurfacePainter extends CustomPainter {
  final bool silver;
  final double sheen;
  final bool pressed;

  _CardSurfacePainter({
    required this.silver,
    required this.sheen,
    required this.pressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (silver) {
      // Exact Mochy 5-stop brushed silver metallic surface
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

      final grainEven = Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
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
              Colors.white.withValues(alpha: 0.50),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
    } else {
      // Exact Mochy matte charcoal #2F2F2F (crisp, timeless, zero neon!)
      canvas.drawRect(rect, Paint()..color = const Color(0xFF2F2F2F));
    }

    if (pressed) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: silver ? 0.24 : 0.10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CardSurfacePainter old) =>
      old.silver != silver || old.sheen != sheen || old.pressed != pressed;
}

class _VerticalMarqueePainter extends CustomPainter {
  final String text;
  final Color color;
  final Color background;
  final double fontSize;
  final String? fontFamily;
  final double progress;

  _VerticalMarqueePainter({
    required this.text,
    required this.color,
    required this.background,
    required this.fontSize,
    this.fontFamily,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fontFamily,
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
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

class ProfileAvatar extends StatelessWidget {
  final UserProfile profile;
  final Color accentColor;
  final double size;
  final Color? borderColor;
  final bool showAddPlaceholder;
  final bool neutralMonochrome;

  const ProfileAvatar({
    super.key,
    required this.profile,
    required this.accentColor,
    this.size = 44,
    this.borderColor,
    this.showAddPlaceholder = false,
    this.neutralMonochrome = false,
  });

  @override
  Widget build(BuildContext context) {
    final path = profile.avatarPath;
    final hasFile =
        !kIsWeb && path != null && path.isNotEmpty && File(path).existsSync();
    final useNeutral = neutralMonochrome && profile.avatarPresetIndex == 0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: useNeutral ? const Color(0xFF4F4F52) : null,
        gradient: useNeutral
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: profile.avatarColors,
              ),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.2)
            : null,
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
                        Icons.add_rounded,
                        color: Colors.white.withValues(alpha: 0.72),
                        size: size * 0.36,
                      )
                    : Text(
                        profile.initials,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.90),
                          fontSize: size * 0.34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
      ),
    );
  }
}
