import 'package:material_ui/material_ui.dart';
import '../models/app_settings.dart';
import '../services/player_controller.dart';
import '../services/settings_controller.dart';
import '../widgets/glass.dart';

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

  String _fmtRemain(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settingsController.settings;
    final accent = s.accentColor;
    final sleepLeft = widget.controller.sleepTimerRemaining;

    return Scaffold(
      backgroundColor: const Color(0xFF06060A),
      body: AmbientBackground(
        artworkUrl: widget.controller.currentTrack?.artworkUrl,
        accentColor: accent,
        style: s.backgroundStyle,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audio Lab',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Chất lượng nhạc • Tốc độ & Cao độ • Equalizer',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 1. Streaming Audio Quality
              SliverToBoxAdapter(
                child: _LabCard(
                  title: 'Chất lượng âm thanh phát trực tuyến',
                  icon: Icons.high_quality_rounded,
                  accent: accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (tier, label) in [
                            (AudioQualityTier.auto, 'Tự động'),
                            (AudioQualityTier.high, 'Cao (AAC HQ)'),
                            (AudioQualityTier.medium, 'Trung bình'),
                            (AudioQualityTier.low, 'Tiết kiệm 4G'),
                          ])
                            _LabChip(
                              label: label,
                              selected: s.audioQuality == tier,
                              accent: accent,
                              onTap: () => widget.settingsController
                                  .setAudioQuality(tier),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Áp dụng ngay cho bài hát kế tiếp hoặc khi phát lại. Luồng M4A AAC chuẩn gốc iOS.',
                        style: TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Real-time Speed, Pitch & Vibe Presets
              SliverToBoxAdapter(
                child: _LabCard(
                  title: 'Hiệu ứng Vibe (Tốc độ & Cao độ thực)',
                  icon: Icons.auto_fix_high_rounded,
                  accent: accent,
                  trailing: TextButton(
                    onPressed: () {
                      widget.settingsController.setPlaybackSpeed(1.0);
                      widget.settingsController.setPlaybackPitch(1.0);
                    },
                    child: Text(
                      'Đặt lại',
                      style: TextStyle(color: accent, fontSize: 12.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _LabChip(
                            label: 'Chuẩn 1.0x',
                            selected: (s.playbackSpeed - 1.0).abs() < 0.02 &&
                                (s.playbackPitch - 1.0).abs() < 0.02,
                            accent: accent,
                            onTap: () {
                              widget.settingsController.setPlaybackSpeed(1.0);
                              widget.settingsController.setPlaybackPitch(1.0);
                            },
                          ),
                          _LabChip(
                            label: 'Slowed Chill',
                            selected: (s.playbackSpeed - 0.85).abs() < 0.03,
                            accent: accent,
                            onTap: () {
                              widget.settingsController.setPlaybackSpeed(0.85);
                              widget.settingsController.setPlaybackPitch(0.90);
                            },
                          ),
                          _LabChip(
                            label: 'Nightcore',
                            selected: (s.playbackSpeed - 1.25).abs() < 0.03,
                            accent: accent,
                            onTap: () {
                              widget.settingsController.setPlaybackSpeed(1.25);
                              widget.settingsController.setPlaybackPitch(1.18);
                            },
                          ),
                          _LabChip(
                            label: 'Podcast 1.5x',
                            selected: (s.playbackSpeed - 1.5).abs() < 0.03,
                            accent: accent,
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
                          const Text('Tốc độ phát', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text(
                            '${s.playbackSpeed.toStringAsFixed(2)}x',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
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
                          const Text('Cao độ (Pitch)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text(
                            '${s.playbackPitch.toStringAsFixed(2)}x',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
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
                    ],
                  ),
                ),
              ),

              // 3. Sleep Timer
              SliverToBoxAdapter(
                child: _LabCard(
                  title: 'Hẹn giờ tắt nhạc',
                  icon: Icons.bedtime_rounded,
                  accent: accent,
                  trailing: sleepLeft != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: accent.withValues(alpha: 0.28),
                          ),
                          child: Text(
                            _fmtRemain(sleepLeft),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mins in [15, 30, 45, 60])
                        _LabChip(
                          label: '$mins phút',
                          selected: false,
                          accent: accent,
                          onTap: () => widget.controller
                              .setSleepTimer(Duration(minutes: mins)),
                        ),
                      if (sleepLeft != null)
                        _LabChip(
                          label: 'Hủy hẹn giờ',
                          selected: true,
                          accent: const Color(0xFFFF6961),
                          onTap: widget.controller.cancelSleepTimer,
                        ),
                    ],
                  ),
                ),
              ),

              // 4. 5-Band Equalizer + Curve Visualizer
              SliverToBoxAdapter(
                child: _LabCard(
                  title: '5-Band Equalizer (${s.eqPreset})',
                  icon: Icons.equalizer_rounded,
                  accent: accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppSettings.eqPresets.keys.map((name) {
                          return _LabChip(
                            label: name,
                            selected: s.eqPreset == name,
                            accent: accent,
                            onTap: () =>
                                widget.settingsController.applyEqPreset(name),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Frequency response curve
                      SizedBox(
                        height: 74,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _EqCurvePainter(
                            bands: s.eqBands,
                            accent: accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 170,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(5, (i) {
                            final db = s.eqBands[i];
                            return Column(
                              children: [
                                Text(
                                  '${db >= 0 ? "+" : ""}${db.round()}dB',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                  ),
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
                                      onChanged: (v) => widget.settingsController
                                          .setEqBand(i, v),
                                    ),
                                  ),
                                ),
                                Text(
                                  _bandLabels[i],
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lưu ý iOS: Tốc độ, Cao độ, Hẹn giờ & Chất lượng nhạc tác động trực tiếp qua AVPlayer gốc. Cấu hình EQ được lưu đồng bộ theo hồ sơ (iOS AVPlayer hạn chế bộ lọc EQ 5 băng tần phần cứng ở mức hệ thống).',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget? trailing;
  final Widget child;

  const _LabCard({
    required this.title,
    required this.icon,
    required this.accent,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: GlassSurface(
        borderRadius: 22,
        blur: 18,
        opacity: 0.10,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _LabChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? accent.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: selected ? accent : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
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
            accent.withValues(alpha: 0.32),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = accent,
    );

    for (final p in pts) {
      canvas.drawCircle(p, 4.2, Paint()..color = Colors.white);
      canvas.drawCircle(p, 2.2, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter old) =>
      old.bands != bands || old.accent != accent;
}
