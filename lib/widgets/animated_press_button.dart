import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable button wrapper that adds a satisfying press animation,
/// ripple glow, and haptic feedback on every tap.
class AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleTo;
  final Duration duration;
  final bool haptic;

  const AnimatedPressButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleTo = 0.94,
    this.duration = const Duration(milliseconds: 100),
    this.haptic = true,
  });

  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleTo).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (widget.onTap == null) return;
    if (widget.haptic) HapticFeedback.lightImpact();
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      onTapDown: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
