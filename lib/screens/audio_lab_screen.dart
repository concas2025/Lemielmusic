import 'package:material_ui/material_ui.dart';
import '../models/app_settings.dart';
import '../services/player_controller.dart';
import '../services/settings_controller.dart';
import '../widgets/glass.dart';

/// Faithful Mochy-Music Audio Lab (`mochy_audiolab.webp`):
/// - Dotted dark charcoal top header with circular back button & massive bold
///   stacked "Audio\nLab" typography.
/// - Pure black sheet below containing 3 iconic borderless #19191C editorial
///   graphic cards (Equalizer, Audio Effect, Audio Quality) that expand smoothly
///   when tapped.
class AudioLabScreen extends StatefulWidget {
  final PlayerController controller;
  final SettingsController settingsController;

  const AudioLabScreen({
    super.key,
    required this.controller,
    required this.settingsController,
  });

  @override
  State<AudioLabScreen> createState() => _AudioLabScreenState();
}

class _AudioLabScreenState extends State<AudioLabScreen> {
  static const _bandLabels = ['60Hz', '230Hz', '910Hz', '3.6k', '14k'];
  String? _expanded; // 'eq' | 'fx' | 'quality'

  @override
  void initState() {
    super.initState();
    widget.settingsController.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_refresh);
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _toggle(String key) {
    setState(() => _expanded = _expanded == key ? null : key);
  }

  String _fmtRemain(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settingsController.settings;
    final accent = s.accentColor;
    final onAccent = s.onAccentColor;
    final sleepLeft = widget.controller.sleepTimerRemaining;

    final eqActive = s.eqPreset != 'Flat';
    final fxActive = (s.playbackSpeed - 1.0).abs() > 0.02 ||
        (s.playbackPitch - 1.0).abs() > 0.02 ||
        sleepLeft != null;

    final qualityCode = switch (s.audioQuality) {
      AudioQualityTier.auto => 'YOUTUBE  ·  AUTO',
      AudioQualityTier.high => 'YOUTUBE  ·  HQ AAC',
      AudioQualityTier.medium => 'YOUTUBE  ·  MEDIUM',
      AudioQualityTier.low => 'YOUTUBE  ·  DATA SAVER',
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Mochy Dotted Header with Massive Stacked "Audio\nLab" Title
          SliverToBoxAdapter(
            child: DottedHeaderSurface(
              bottomRadius: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SpringTap(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF3A3A3E),
                          ),
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Audio\nLab',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.6,
                          height: 1.02,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Lower Pure Black Sheet with 3 Mochy Graphic Feature Cards
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 48),
              child: Column(
                children: [
                  // 1. EQUALIZER CARD
                  _MochyLabTile(
                    statusText: eqActive ? s.eqPreset.toUpperCase() : 'OFF',
                    statusActive: eqActive,
                    title: 'Equalizer',
                    expanded: _expanded == 'eq',
                    accent: accent,
                    graphic: CustomPaint(
                      painter: _EqFaderGraphicPainter(),
                    ),
                    onTap: () => _toggle('eq'),
                    expandedChild: _buildEqPanel(s, accent, onAccent),
                  ),
                  const SizedBox(height: 14),

                  // 2. AUDIO EFFECT CARD (Speed, Pitch, Vibe Presets, Sleep Timer)
                  _MochyLabTile(
                    statusText: fxActive
                        ? '${s.playbackSpeed.toStringAsFixed(2)}x${sleepLeft != null ? " · ${_fmtRemain(sleepLeft)}" : ""}'
                        : 'ALL OFF',
                    statusActive: fxActive,
                    title: 'Audio Effect',
                    expanded: _expanded == 'fx',
                    accent: accent,
                    graphic: CustomPaint(
                      painter: _FxWatermarkPainter(
                        fontFamily:
                            DefaultTextStyle.of(context).style.fontFamily,
                      ),
                    ),
                    onTap: () => _toggle('fx'),
                    expandedChild: _buildFxPanel(s, accent, onAccent, sleepLeft),
                  ),
                  const SizedBox(height: 14),

                  // 3. AUDIO QUALITY CARD
                  _MochyQualityCard(
                    subtitle: qualityCode,
                    expanded: _expanded == 'quality',
                    onTap: () => _toggle('quality'),
                    expandedChild: _buildQualityPanel(s, accent, onAccent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEqPanel(AppSettings s, Color accent, Color onAccent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppSettings.eqPresets.keys.map((name) {
            final sel = s.eqPreset == name;
            return _MonoChip(
              label: name,
              selected: sel,
              accent: accent,
              onAccent: onAccent,
              onTap: () => widget.settingsController.applyEqPreset(name),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 68,
          width: double.infinity,
          child: CustomPaint(
            painter: _EqCurvePainter(bands: s.eqBands, accent: accent),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final db = s.eqBands[i];
              return Column(
                children: [
                  Text(
                    '${db >= 0 ? "+" : ""}${db.round()}',
                    style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 10.5),
                  ),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        value: db,
                        min: -12,
                        max: 12,
                        activeColor: accent,
                        inactiveColor: Colors.white24,
                        onChanged: (v) =>
                            widget.settingsController.setEqBand(i, v),
                      ),
                    ),
                  ),
                  Text(
                    _bandLabels[i],
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Lưu ý iOS: Tốc độ, cao độ, hẹn giờ & chất lượng nhạc tác động trực tiếp qua AVPlayer; cấu hình EQ được lưu đồng bộ theo hồ sơ.',
          style: TextStyle(color: Color(0xFF636366), fontSize: 11, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildFxPanel(
    AppSettings s,
    Color accent,
    Color onAccent,
    Duration? sleepLeft,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MonoChip(
              label: 'Chuẩn 1.0x',
              selected: (s.playbackSpeed - 1.0).abs() < 0.02 &&
                  (s.playbackPitch - 1.0).abs() < 0.02,
              accent: accent,
              onAccent: onAccent,
              onTap: () {
                widget.settingsController.setPlaybackSpeed(1.0);
                widget.settingsController.setPlaybackPitch(1.0);
              },
            ),
            _MonoChip(
              label: 'Slowed Chill',
              selected: (s.playbackSpeed - 0.85).abs() < 0.03,
              accent: accent,
              onAccent: onAccent,
              onTap: () {
                widget.settingsController.setPlaybackSpeed(0.85);
                widget.settingsController.setPlaybackPitch(0.90);
              },
            ),
            _MonoChip(
              label: 'Nightcore',
              selected: (s.playbackSpeed - 1.25).abs() < 0.03,
              accent: accent,
              onAccent: onAccent,
              onTap: () {
                widget.settingsController.setPlaybackSpeed(1.25);
                widget.settingsController.setPlaybackPitch(1.18);
              },
            ),
            _MonoChip(
              label: 'Podcast 1.5x',
              selected: (s.playbackSpeed - 1.5).abs() < 0.03,
              accent: accent,
              onAccent: onAccent,
              onTap: () {
                widget.settingsController.setPlaybackSpeed(1.5);
                widget.settingsController.setPlaybackPitch(1.0);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tốc độ phát', style: TextStyle(color: Color(0xFFAEAEB2), fontSize: 13)),
            Text('${s.playbackSpeed.toStringAsFixed(2)}x',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: s.playbackSpeed,
          min: 0.5,
          max: 2.0,
          divisions: 30,
          activeColor: accent,
          inactiveColor: Colors.white24,
          onChanged: widget.settingsController.setPlaybackSpeed,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Cao độ (Pitch)', style: TextStyle(color: Color(0xFFAEAEB2), fontSize: 13)),
            Text('${s.playbackPitch.toStringAsFixed(2)}x',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: s.playbackPitch,
          min: 0.5,
          max: 2.0,
          divisions: 30,
          activeColor: accent,
          inactiveColor: Colors.white24,
          onChanged: widget.settingsController.setPlaybackPitch,
        ),
        const SizedBox(height: 8),
        const Text('Hẹn giờ tắt nhạc',
            style: TextStyle(color: Color(0xFFAEAEB2), fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mins in [15, 30, 45, 60])
              _MonoChip(
                label: '$mins phút',
                selected: false,
                accent: accent,
                onAccent: onAccent,
                onTap: () =>
                    widget.controller.setSleepTimer(Duration(minutes: mins)),
              ),
            if (sleepLeft != null)
              _MonoChip(
                label: 'Hủy (${_fmtRemain(sleepLeft)})',
                selected: true,
                accent: accent,
                onAccent: onAccent,
                onTap: widget.controller.cancelSleepTimer,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQualityPanel(AppSettings s, Color accent, Color onAccent) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (tier, label) in [
          (AudioQualityTier.auto, 'Tự động'),
          (AudioQualityTier.high, 'Cao (AAC HQ)'),
          (AudioQualityTier.medium, 'Trung bình'),
          (AudioQualityTier.low, 'Tiết kiệm 4G'),
        ])
          _MonoChip(
            label: label,
            selected: s.audioQuality == tier,
            accent: accent,
            onAccent: onAccent,
            onTap: () => widget.settingsController.setAudioQuality(tier),
          ),
      ],
    );
  }
}

class _MochyLabTile extends StatelessWidget {
  final String statusText;
  final bool statusActive;
  final String title;
  final bool expanded;
  final Color accent;
  final Widget graphic;
  final VoidCallback onTap;
  final Widget expandedChild;

  const _MochyLabTile({
    required this.statusText,
    required this.statusActive,
    required this.title,
    required this.expanded,
    required this.accent,
    required this.graphic,
    required this.onTap,
    required this.expandedChild,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF19191C),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SpringTap(
            pressedScale: 0.985,
            onTap: onTap,
            child: SizedBox(
              height: 126,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned(
                    right: -6,
                    top: -6,
                    bottom: -6,
                    width: 150,
                    child: IgnorePointer(child: graphic),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusActive
                                    ? accent
                                    : const Color(0xFF636366),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusActive
                                    ? Colors.white
                                    : const Color(0xFF8E8E93),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Container(height: 0.6, color: const Color(0xFF28282D)),
                  const SizedBox(height: 16),
                  expandedChild,
                ],
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _MochyQualityCard extends StatelessWidget {
  final String subtitle;
  final bool expanded;
  final VoidCallback onTap;
  final Widget expandedChild;

  const _MochyQualityCard({
    required this.subtitle,
    required this.expanded,
    required this.onTap,
    required this.expandedChild,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF19191C),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          SpringTap(
            pressedScale: 0.985,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Audio Quality',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    height: 36,
                    child: CustomPaint(painter: _WaveformGraphicPainter()),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: expandedChild,
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _MonoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color onAccent;
  final VoidCallback onTap;

  const _MonoChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onAccent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? accent : const Color(0xFF26262B),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? onAccent : const Color(0xFFAEAEB2),
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EqFaderGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * 0.55, size.height * 0.55);
    canvas.rotate(-0.22);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.22);

    final box = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-54, -56, 118, 122),
      const Radius.circular(24),
    );
    canvas.drawRRect(box, stroke);

    final xs = [-26.0, 4.0, 34.0];
    final ys = [16.0, -8.0, 22.0];
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(Offset(xs[i], -36), Offset(xs[i], ys[i] - 11), stroke);
      canvas.drawLine(Offset(xs[i], ys[i] + 11), Offset(xs[i], 46), stroke);
      canvas.drawCircle(Offset(xs[i], ys[i]), 10, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FxWatermarkPainter extends CustomPainter {
  final String? fontFamily;
  const _FxWatermarkPainter({this.fontFamily});

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'FX',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 96,
          fontWeight: FontWeight.w900,
          letterSpacing: -3.0,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(alpha: 0.22),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width + 6, (size.height - tp.height) / 2 + 4));
  }

  @override
  bool shouldRepaint(covariant _FxWatermarkPainter oldDelegate) =>
      oldDelegate.fontFamily != fontFamily;
}

class _WaveformGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const heights = [
      0.25, 0.55, 0.85, 0.45, 0.95, 0.65, 0.30, 0.70, 0.90, 0.40,
      0.60, 0.30, 0.50, 0.80, 0.65, 0.35, 0.45, 0.22,
    ];
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.36)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final step = size.width / heights.length;
    final cy = size.height / 2;
    for (int i = 0; i < heights.length; i++) {
      final x = i * step + step / 2;
      final h = size.height * heights[i] * 0.5;
      canvas.drawLine(Offset(x, cy - h), Offset(x, cy + h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EqCurvePainter extends CustomPainter {
  final List<double> bands;
  final Color accent;

  _EqCurvePainter({required this.bands, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1,
    );

    final pts = <Offset>[];
    for (int i = 0; i < bands.length; i++) {
      final x = (size.width / (bands.length - 1)) * i;
      final norm = (bands[i] / 12.0).clamp(-1.0, 1.0);
      final y = midY - norm * (size.height * 0.40);
      pts.add(Offset(x, y));
    }

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      line.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.25),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = accent,
    );

    for (final p in pts) {
      canvas.drawCircle(p, 4.0, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter old) =>
      old.bands != bands || old.accent != accent;
}
