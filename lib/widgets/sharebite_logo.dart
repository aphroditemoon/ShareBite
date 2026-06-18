import 'package:flutter/material.dart';

class ShareBiteLogo extends StatelessWidget {
  final double size;
  final double radius;
  final bool shadow;
  final BoxFit fit;
  const ShareBiteLogo({
    super.key,
    this.size = 84,
    this.radius = 26,
    this.shadow = true,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Image.asset('assets/images/sharebite_logo.png', fit: fit),
    );
  }
}
