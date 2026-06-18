import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/listing_model.dart';
import '../theme/app_theme.dart';

// Real food image pool — Unsplash (no emoji)
const _foodImages = [
  'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
  'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=400',
  'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400',
  'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400',
  'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400',
  'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400',
  'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=400',
  'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400',
  'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400',
  'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=400',
];

const _nonfoodImages = [
  'https://images.unsplash.com/photo-1491553895911-0055eca6402d?w=400',
  'https://images.unsplash.com/photo-1524117074681-31bd4de22ad3?w=400',
  'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=400',
  'https://images.unsplash.com/photo-1507646227500-4d389b0012be?w=400',
  'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?w=400',
];

String getFallbackImage(ListingModel listing) {
  final seed = listing.id.isNotEmpty ? listing.id.codeUnitAt(0) : 0;
  if (listing.category == 'free_nonfood' ||
      listing.category == 'for_sale' ||
      listing.category == 'borrow') {
    return _nonfoodImages[seed % _nonfoodImages.length];
  }
  return _foodImages[seed % _foodImages.length];
}

class ListingCard extends StatefulWidget {
  final ListingModel listing;
  final VoidCallback onTap;
  const ListingCard({super.key, required this.listing, required this.onTap});

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _elevAnim;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _elevAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    HapticFeedback.selectionClick();
    await _ctrl.forward();
    if (mounted) await _ctrl.reverse();
    widget.onTap();
  }

  bool _isLocalImage(String url) => url.startsWith('file://');

  String _localImagePath(String url) {
    if (!url.startsWith('file://')) return url;
    return Uri.parse(url).toFilePath(windows: Platform.isWindows);
  }

  Widget _buildImage(String imageUrl, Color catColor) {
    if (_isLocalImage(imageUrl)) {
      return Image.file(
        File(_localImagePath(imageUrl)),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          color: catColor.withOpacity(0.1),
          child:
              Icon(Icons.image_outlined, color: catColor.withOpacity(0.4), size: 36),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: catColor.withOpacity(0.08),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: catColor.withOpacity(0.4)),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: catColor.withOpacity(0.1),
        child:
            Icon(Icons.image_outlined, color: catColor.withOpacity(0.4), size: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final catColor = AppTheme.categoryColors[l.category] ?? AppTheme.primary;
    final imageUrl =
        l.firstImageUrl.isNotEmpty ? l.firstImageUrl : getFallbackImage(l);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.skyGradientFor(context,
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05 * _elevAnim.value),
                blurRadius: 16 * _elevAnim.value,
                offset: Offset(0, 4 * _elevAnim.value),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) async {
          await _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  SizedBox.expand(child: _buildImage(imageUrl, catColor)),
                  // Category pill
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppTheme.gradientFor(catColor),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l.isFree ? 'FREE' : _formatPrice(l.price),
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3),
                      ),
                    ),
                  ),
                  // Animated bookmark
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _BookmarkButton(
                      saved: _saved,
                      onToggle: () {
                        HapticFeedback.lightImpact();
                        setState(() => _saved = !_saved);
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Info area
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.title,
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.txtPrimary(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (l.owner != null)
                      Row(children: [
                        Icon(Icons.person_outline_rounded,
                            size: 12, color: AppTheme.txtSecondary(context)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            l.owner!.name,
                            style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                color: AppTheme.txtSecondary(context),
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    const Spacer(),
                    Row(children: [
                      Icon(Icons.location_on_outlined, size: 12, color: catColor),
                      const SizedBox(width: 2),
                      Text(
                        l.distanceText.isNotEmpty
                            ? l.distanceText
                            : timeago.format(l.createdAt),
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: catColor,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double p) {
    if (p >= 1000000) return 'Rp${(p / 1000000).toStringAsFixed(1)}M';
    if (p >= 1000) return 'Rp${(p / 1000).toStringAsFixed(0)}K';
    return 'Rp${p.toStringAsFixed(0)}';
  }
}

/// Animated bookmark button with spring bounce and fill animation
class _BookmarkButton extends StatefulWidget {
  final bool saved;
  final VoidCallback onToggle;
  const _BookmarkButton({required this.saved, required this.onToggle});

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 0.9)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.9, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30),
    ]).animate(_ctrl);
    _bounce = _scale;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _BookmarkButton old) {
    super.didUpdateWidget(old);
    if (widget.saved != old.saved) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (_, __) => Transform.scale(
          scale: _bounce.value,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? AppTheme.inputDark.withOpacity(0.92)
                  : Colors.white.withOpacity(0.92),
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                widget.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                key: ValueKey(widget.saved),
                size: 15,
                color: widget.saved
                    ? AppTheme.primary
                    : AppTheme.txtSecondary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
