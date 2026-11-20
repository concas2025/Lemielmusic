import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../theme/lemiel_theme.dart';
import 'glass.dart';

class LiquidDockItem {
  final IconData icon;
  final String label;
  const LiquidDockItem({required this.icon, required this.label});
}

/// BitChord / iOS 26 smoked Liquid Glass Floating Bottom Dock:
/// - Monochrome obsidian glass capsule with spring-physics translucent selection
///   pill (pure white active icon, #8E8E93 inactive, zero red clutter).
/// - Separated circular Liquid Glass Search Orb on the right.
class LiquidFloatingDock extends StatefulWidget {
  final List<LiquidDockItem> items;
  final int activeIndex;
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
    const spring = SpringDescription(mass: 1.0, stiffness: 360, damping: 25);
    _lensPos.animateWith(SpringSimulation(spring, _lensPos.value, target, 0));
  }

  @override
  void dispose() {
    _lensPos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = LemielTheme.of(context);
    final activeTint = widget.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: GlassSurface(
              borderRadius: 31,
              blur: 24,
              isLens: true,
              highQuality: widget.highGlass,
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                height: 52,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final count = widget.items.length;
                    final tabWidth = constraints.maxWidth / count;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) =>
                          setState(() => _isDragging = true),
                      onHorizontalDragUpdate: (details) {
                        final pos = (details.localPosition.dx / tabWidth - 0.5)
                            .clamp(0.0, (count - 1).toDouble());
                        _lensPos.value = pos;
                      },
                      onHorizontalDragEnd: (_) {
                        setState(() => _isDragging = false);
                        final target =
                            _lensPos.value.round().clamp(0, count - 1);
                        _springTo(target.toDouble());
                        if (target != widget.activeIndex) {
                          HapticFeedback.selectionClick();
                          widget.onSelect(target);
                        }
                      },
                      child: Stack(
                        children: [
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
                                    scale: _isDragging ? 1.04 : 1.0,
                                    duration: const Duration(milliseconds: 160),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(26),
                                        color: theme.isClassic
                                            ? const Color(0xFF2D2D33)
                                            : Colors.white
                                                .withValues(alpha: 0.14),
                                        border: theme.isClassic
                                            ? null
                                            : Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.16),
                                                width: 0.6,
                                              ),
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
                                        scale: active ? 1.06 : 1.0,
                                        duration:
                                            const Duration(milliseconds: 180),
                                        curve: Curves.easeOutBack,
                                        child: Icon(
                                          item.icon,
                                          size: 21,
                                          color: active
                                              ? activeTint
                                              : const Color(0xFF8E8E93),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: active
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: active
                                              ? activeTint
                                              : const Color(0xFF8E8E93),
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
          const SizedBox(width: 10),
          // Separated circular BitChord Liquid Glass Search Orb
          SpringTap(
            pressedScale: 0.90,
            onTap: () => widget.onSelect(widget.items.length),
            child: GlassSurface(
              borderRadius: 30,
              blur: 24,
              isLens: true,
              highQuality: widget.highGlass,
              child: Container(
                width: 60,
                height: 60,
                decoration: _isSearchActive
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                      )
                    : null,
                child: Icon(
                  Icons.search_rounded,
                  size: 25,
                  color: _isSearchActive
                      ? activeTint
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
