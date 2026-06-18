import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedCategoryChip extends StatefulWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final EdgeInsets padding;
  final double radius;
  final double fontSize;

  const AnimatedCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.radius = 24,
    this.fontSize = 13,
  });

  @override
  State<AnimatedCategoryChip> createState() => _AnimatedCategoryChipState();
}

class _AnimatedCategoryChipState extends State<AnimatedCategoryChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      reverseDuration: const Duration(milliseconds: 170),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _pressCtrl.forward();
    if (mounted) await _pressCtrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          margin: const EdgeInsets.only(right: 8),
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: widget.selected ? AppTheme.gradientFor(widget.color) : null,
            color: widget.selected ? null : widget.color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: widget.color.withOpacity(widget.selected ? 0.0 : 0.26),
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w800,
              color: widget.selected ? Colors.white : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
