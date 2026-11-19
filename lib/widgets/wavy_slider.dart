import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../models/app_settings.dart';

/// Customizable Seek Bar supporting Apple Slim, Mochy Wavy (animated wave),
/// and Liquid Pill styles.
class CustomMusicSlider extends StatefulWidget {
  final double value; // 0.0..1.0
  final bool isPlaying;
  final SliderStyle style;
  final Color accentColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const CustomMusicSlider({
    super.key,
    required this.value,
    required this.isPlaying,
    required this.style,
    required this.accentColor,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  State<CustomMusicSlider> createState() => _CustomMusicSliderState();
}

class _CustomMusicSliderState extends State<CustomMusicSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isPlaying && widget.style == SliderStyle.mochyWavy) {
      _waveCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CustomMusicSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldWave = widget.isPlaying && widget.style == SliderStyle.mochyWavy;
    if (shouldWave && !_waveCtrl.isAnimating) {
      _waveCtrl.repeat();
    } else if (!shouldWave && _waveCtrl.isAnimating) {
      _waveCtrl.stop();
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  double _dxToFraction(double dx, double width) =>
      width <= 0 ? 0.0 : (dx / width).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final progress = widget.value.clamp(0.0, 1.0);

    if (widget.style == SliderStyle.appleSlim) {
      return SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: _dragging ? 6 : 4,
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: _dragging ? 7.5 : 5.5,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.20),
          thumbColor: Colors.white,
        ),
        child: Slider(
          value: progress,
          onChangeStart: (_) => setState(() => _dragging = true),
          onChanged: widget.onChanged,
          onChangeEnd: (v) {
            setState(() => _dragging = false);
            widget.onChangeEnd(v);
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final f = _dxToFraction(d.localPosition.dx, w);
            widget.onChanged(f);
            widget.onChangeEnd(f);
          },
          onHorizontalDragStart: (d) {
            setState(() => _dragging = true);
            widget.onChanged(_dxToFraction(d.localPosition.dx, w));
          },
          onHorizontalDragUpdate: (d) {
            widget.onChanged(_dxToFraction(d.localPosition.dx, w));
          },
          onHorizontalDragEnd: (_) {
            setState(() => _dragging = false);
            widget.onChangeEnd(progress);
          },
          child: SizedBox(
            height: 36,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, _) => CustomPaint(
                painter: widget.style == SliderStyle.mochyWavy
                    ? _MochyWavePainter(
                        progress: progress,
                        phase: _waveCtrl.value * 2 * math.pi,
                        amplitude: widget.isPlaying && !_dragging ? 3.2 : 0.6,
                        accentColor: widget.accentColor,
                        dragging: _dragging,
                      )
                    : _LiquidPillSliderPainter(
                        progress: progress,
                        accentColor: widget.accentColor,
                        dragging: _dragging,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MochyWavePainter extends CustomPainter {
  final double progress;
  final double phase;
  final double amplitude;
  final Color accentColor;
  final bool dragging;

  _MochyWavePainter({
    required this.progress,
    required this.phase,
    required this.amplitude,
    required this.accentColor,
    required this.dragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final activeX = (size.width * progress).clamp(0.0, size.width);

    // Inactive straight track
    final inactivePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    if (activeX < size.width) {
      canvas.drawLine(
        Offset(activeX, cy),
        Offset(size.width, cy),
        inactivePaint,
      );
    }

    // Active wavy path
    if (activeX > 1) {
      final path = Path();
      const wavelength = 24.0;
      path.moveTo(0, cy);
      for (double x = 0; x <= activeX; x += 2.5) {
        final fade = math.min(1.0, (activeX - x) / 14.0).clamp(0.0, 1.0);
        final y = cy + math.sin((x / wavelength) * 2 * math.pi - phase) * amplitude * fade;
        path.lineTo(x, y);
      }
      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = dragging ? 4.2 : 3.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.92),
            accentColor,
          ],
        ).createShader(Rect.fromLTWH(0, 0, activeX, size.height));
      canvas.drawPath(path, activePaint);
    }

    // Vertical pill thumb (Mochy signature)
    final thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(activeX.clamp(4.0, size.width - 4.0), cy),
        width: dragging ? 6.5 : 4.5,
        height: dragging ? 20 : 15,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      thumbRect,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _MochyWavePainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.amplitude != amplitude ||
      old.dragging != dragging ||
      old.accentColor != accentColor;
}

class _LiquidPillSliderPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final bool dragging;

  _LiquidPillSliderPainter({
    required this.progress,
    required this.accentColor,
    required this.dragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final h = dragging ? 12.0 : 8.5;
    final r = Radius.circular(h / 2);

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width / 2, cy), width: size.width, height: h),
      r,
    );
    canvas.drawRRect(bgRect, Paint()..color = Colors.white.withValues(alpha: 0.16));

    final activeW = (size.width * progress).clamp(h, size.width);
    final fgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, cy - h / 2, activeW, h),
      r,
    );
    final fgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          accentColor.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.95),
        ],
      ).createShader(fgRect.outerRect);
    canvas.drawRRect(fgRect, fgPaint);

    // Subtle specular border around capsule
    canvas.drawRRect(
      bgRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidPillSliderPainter old) =>
      old.progress != progress ||
      old.dragging != dragging ||
      old.accentColor != accentColor;
}
