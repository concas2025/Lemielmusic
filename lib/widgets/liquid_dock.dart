import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'glass.dart';

class LiquidDockItem {
  final IconData icon;
  final String label;
  const LiquidDockItem({required this.icon, required this.label});
}

/// BitChord / iOS 26 style floating Liquid Glass Navigation Dock:
/// - Main floating Liquid Glass capsule with a spring-physics sliding Lens pill
///   that supports both tap and horizontal drag-scrubbing across tabs.
/// - Separated circular Liquid Glass Search Orb on the right (index == items.length).
class LiquidFloatingDock extends StatefulWidget {
  final List<LiquidDockItem> items;
  final int activeIndex; // 0..items.length-1 = dock tabs, items.length = search orb
  final Color accentColor;
  final bool highGlass;
  final ValueChanged<int> onSelect;

  const LiquidFloatingDock({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.accentColor,
    required this.highGlass,
    required this.onSelect,
  });

  @override
  State<LiquidFloatingDock> createState() => _LiquidFloatingDockState();
}

class _LiquidFloatingDockState extends State<LiquidFloatingDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lensPos;
  bool _isDragging = false;

  int get _clampedDockIndex =>
      widget.activeIndex.clamp(0, widget.items.length - 1);

  bool get _isSearchActive => widget.activeIndex == widget.items.length;

  @override
  void initState() {
    super.initState();
    _lensPos = AnimationController.unbounded(
      vsync: this,
      value: _clampedDockIndex.toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant LiquidFloatingDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging &&
        !_isSearchActive &&
        oldWidget.activeIndex != widget.activeIndex) {
      _springTo(_clampedDockIndex.toDouble());
    }
  }

  void _springTo(double target) {
    const spring = SpringDescription(mass: 1.0, stiffness: 360, damping: 24);
    _lensPos.animateWith(SpringSimulation(spring, _lensPos.value, target, 0));
  }

  @override
  void dispose() {
    _lensPos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          // Main Liquid Glass Tab Capsule
          Expanded(
            child: GlassSurface(
              borderRadius: 32,
              blur: 22,
              opacity: 0.16,
              tintColor: const Color(0xFF1A1A26),
              isLens: true,
              highQuality: widget.highGlass,
              padding: const EdgeInsets.all(5),
              child: SizedBox(
                height: 52,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final count = widget.items.length;
                    final tabWidth = constraints.maxWidth / count;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) {
                        setState(() => _isDragging = true);
                      },
                      onHorizontalDragUpdate: (details) {
                        final pos = (details.localPosition.dx / tabWidth - 0.5)
                            .clamp(0.0, (count - 1).toDouble());
                        _lensPos.value = pos;
                      },
                      onHorizontalDragEnd: (_) {
                        setState(() => _isDragging = false);
                        final target = _lensPos.value.round().clamp(0, count - 1);
                        _springTo(target.toDouble());
                        if (target != widget.activeIndex) {
                          HapticFeedback.selectionClick();
                          widget.onSelect(target);
                        }
                      },
                      child: Stack(
                        children: [
                          // Sliding Liquid Glass Selection Lens
                          if (!_isSearchActive)
                            AnimatedBuilder(
                              animation: _lensPos,
                              builder: (_, _) {
                                final clamped = _lensPos.value
                                    .clamp(0.0, (count - 1).toDouble());
                                return Positioned(
                                  left: clamped * tabWidth,
                                  top: 0,
                                  bottom: 0,
                                  width: tabWidth,
                                  child: AnimatedScale(
                                    scale: _isDragging ? 1.06 : 1.0,
                                    duration: const Duration(milliseconds: 160),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(26),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withValues(alpha: 0.22),
                                            widget.accentColor
                                                .withValues(alpha: 0.16),
                                          ],
                                        ),
                                        border: Border.all(
                                          color:
                                              Colors.white.withValues(alpha: 0.30),
                                          width: 0.9,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: widget.accentColor
                                                .withValues(alpha: 0.22),
                                            blurRadius: 14,
                                            spreadRadius: -2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          Row(
                            children: List.generate(count, (i) {
                              final item = widget.items[i];
                              final active = widget.activeIndex == i;
                              return Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _springTo(i.toDouble());
                                    widget.onSelect(i);
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: active ? 1.1 : 1.0,
                                        duration:
                                            const Duration(milliseconds: 220),
                                        curve: Curves.easeOutBack,
                                        child: Icon(
                                          item.icon,
                                          size: 22,
                                          color: active
                                              ? widget.accentColor
                                              : Colors.white
                                                  .withValues(alpha: 0.62),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: active
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: active
                                              ? Colors.white
                                              : Colors.white
                                                  .withValues(alpha: 0.58),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Separated Circular Liquid Glass Search Orb (iOS 26 / BitChord)
          SpringTap(
            pressedScale: 0.88,
            onTap: () => widget.onSelect(widget.items.length),
            child: GlassSurface(
              borderRadius: 32,
              blur: 22,
              opacity: _isSearchActive ? 0.30 : 0.16,
              tintColor: _isSearchActive
                  ? widget.accentColor
                  : const Color(0xFF1A1A26),
              isLens: true,
              highQuality: widget.highGlass,
              child: SizedBox(
                width: 62,
                height: 62,
                child: Icon(
                  Icons.search_rounded,
                  size: 26,
                  color: _isSearchActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
