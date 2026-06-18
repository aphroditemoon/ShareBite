import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/listing_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/animated_category_chip.dart';
import '../listing/listing_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onExploreNow;
  final int refreshVersion;
  const HomeScreen({super.key, this.onExploreNow, this.refreshVersion = 0});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<ListingModel> _listings = [];
  bool _loading = true;
  String _selectedCategory = 'all';
  Position? _position;
  final ScrollController _scrollCtrl = ScrollController();

  // Staggered entry animations
  late final AnimationController _entranceCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _gridFade;

  // Notification bell pulse
  late final AnimationController _bellCtrl;
  late final Animation<double> _bellScale;

  final _categories = [
    {'id': 'all', 'label': 'All'},
    {'id': 'free_food', 'label': 'Free Food'},
    {'id': 'free_nonfood', 'label': 'Free Non-Food'},
    {'id': 'for_sale', 'label': 'For Sale'},
    {'id': 'borrow', 'label': 'Borrow'},
    {'id': 'wanted', 'label': 'Wanted'},
  ];

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0, 0.4, curve: Curves.easeOut)));
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0, 0.5, curve: Curves.easeOutCubic)));
    _heroFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.2, 0.6, curve: Curves.easeOut)));
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic)));
    _gridFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

    _bellCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _bellScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 40),
    ]).animate(_bellCtrl);

    _entranceCtrl.forward();
    _getLocation();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _bellCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshVersion != oldWidget.refreshVersion) {
      _fetchListings();
    }
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.deniedForever) {
        _position = await Geolocator.getCurrentPosition();
      }
    } catch (_) {}
    _fetchListings();
  }

  Future<void> _fetchListings() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.getListings(
        lat: _position?.latitude,
        lng: _position?.longitude,
        category: _selectedCategory,
        radius: 100000,
        sort: 'newest',
      );
      if (res['success'] == true) {
        final data = res['data']['listings'] as List;
        if (!mounted) return;
        setState(() => _listings = data.map((e) => ListingModel.fromJson(e)).toList());
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: RefreshIndicator(
        onRefresh: _fetchListings,
        color: AppTheme.primary,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // ── Seamless blue block: header + hero banner + category filter ──
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.skyGradientFor(context,
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Greeting row ──
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              20, MediaQuery.of(context).padding.top + 16, 20, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_getGreeting(),
                                        style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 13,
                                            color: AppTheme.txtSecondary(context),
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text(
                                      user?.name.split(' ').first ?? 'there',
                                      style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.txtPrimary(context)),
                                    ),
                                  ],
                                ),
                              ),
                              // Animated notification bell
                              AnimatedBuilder(
                                animation: _bellScale,
                                builder: (_, __) => Transform.scale(
                                  scale: _bellScale.value,
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _bellCtrl.forward(from: 0);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('No new notifications right now 🔔'),
                                          backgroundColor: AppTheme.primary,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14)),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient(),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.notifications_outlined,
                                          color: Colors.white, size: 22),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Hero banner ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          child: Container(
                            height: 148,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: AppTheme.primaryGradient(),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned(
                                    right: -30,
                                    top: -30,
                                    child: Container(
                                        width: 160,
                                        height: 160,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withOpacity(0.08)))),
                                Positioned(
                                    right: 60,
                                    bottom: -50,
                                    child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withOpacity(0.06)))),
                                // Food photo collage
                                Positioned(
                                  right: 12,
                                  top: 12,
                                  bottom: 12,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: 110,
                                      child: Column(
                                        children: [
                                          Expanded(
                                              child: _heroImg(
                                                  'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=200')),
                                          const SizedBox(height: 4),
                                          Expanded(
                                              child: Row(children: [
                                            Expanded(
                                                child: _heroImg(
                                                    'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=200')),
                                            const SizedBox(width: 4),
                                            Expanded(
                                                child: _heroImg(
                                                    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=200')),
                                          ])),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Text + animated button
                                Positioned(
                                  left: 20,
                                  top: 20,
                                  bottom: 20,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Share food,',
                                          style: TextStyle(
                                              fontFamily: 'Nunito',
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800)),
                                      Text('share love',
                                          style: TextStyle(
                                              fontFamily: 'Nunito',
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 8),
                                      _HeroPulseButton(onTap: widget.onExploreNow),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Category filter ──
                        SizedBox(
                          height: 42,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _categories.length,
                            itemBuilder: (_, i) {
                              final cat = _categories[i];
                              final sel = _selectedCategory == cat['id'];
                              final color = i == 0
                                  ? AppTheme.primary
                                  : (AppTheme.categoryColors[cat['id']] ??
                                      AppTheme.primary);
                              return AnimatedCategoryChip(
                                label: cat['label']!,
                                selected: sel,
                                color: color,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedCategory = cat['id']!);
                                  _fetchListings();
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Section header
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _gridFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _position != null ? 'Near you' : 'All listings',
                          style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.txtPrimary(context)),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          '${_listings.length} items',
                          key: ValueKey(_listings.length),
                          style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Grid
            if (_loading)
              SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: _buildShimmer())
            else if (_listings.isEmpty)
              SliverToBoxAdapter(child: _buildEmpty())
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      // Stagger each card's appearance
                      final delay = (i * 60).clamp(0, 400);
                      return _StaggeredCard(
                        delay: delay,
                        child: ListingCard(
                          listing: _listings[i],
                          onTap: () => Navigator.push(
                            context,
                            _SlideRoute(child: ListingDetailScreen(listingId: _listings[i].id)),
                          ),
                        ),
                      );
                    },
                    childCount: _listings.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.70,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _heroImg(String url) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) =>
                Container(color: Colors.white.withOpacity(0.2))),
      );

  SliverGrid _buildShimmer() {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (_, i) => _ShimmerCard(index: i),
        childCount: 6,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.70,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (_, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.search_off_rounded,
                color: AppTheme.primary, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        Text('Nothing here yet',
            style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.txtPrimary(context))),
        const SizedBox(height: 8),
        Text(
          'Try expanding your search radius or changing the filter',
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: AppTheme.txtSecondary(context),
              height: 1.5),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

/// Pulsing explore button with shimmer + glow animation
class _HeroPulseButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _HeroPulseButton({this.onTap});

  @override
  State<_HeroPulseButton> createState() => _HeroPulseButtonState();
}

class _HeroPulseButtonState extends State<_HeroPulseButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _pressCtrl;

  late final Animation<double> _pulse;
  late final Animation<double> _shimmer;
  late final Animation<double> _glow;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();

    // Gentle breathing pulse
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.055)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 0.3, end: 0.9)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Shimmer sweep
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    // Press bounce
    _pressCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 80),
        reverseDuration: const Duration(milliseconds: 200));
    _pressScale = Tween<double>(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    // Fire action immediately — no lag
    widget.onTap?.call();
    // Animate after
    _pressCtrl.forward().then((_) {
      if (mounted) _pressCtrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _shimmerCtrl, _pressCtrl]),
      builder: (_, __) {
        return Transform.scale(
          scale: _pulse.value * _pressScale.value,
          child: GestureDetector(
            onTap: _handleTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.isDark(context)
                    ? AppTheme.inputDark.withOpacity(0.92)
                    : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.45), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryLight.withOpacity(_glow.value * 0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Button text
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Explore now',
                            style: TextStyle(
                                fontFamily: 'Nunito',
                                color: AppTheme.primaryDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 13, color: AppTheme.primaryDark),
                      ],
                    ),
                    // Shimmer sweep overlay
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(_shimmer.value * 80, 0),
                        child: Container(
                          width: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.5),
                                Colors.white.withOpacity(0.0),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Staggered card wrapper for grid entrance
class _StaggeredCard extends StatefulWidget {
  final Widget child;
  final int delay;
  const _StaggeredCard({required this.child, required this.delay});

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}

/// Shimmer skeleton card with pulsing animation
class _ShimmerCard extends StatefulWidget {
  final int index;
  const _ShimmerCard({required this.index});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    // offset shimmer phase per card
    _shimmer = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    // stagger start
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      // already repeating
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, __) {
        final c = Color.lerp(const Color(0xFFE8F4FF), const Color(0xFFC8E0F4), _shimmer.value)!;
        final isDark = AppTheme.isDark(context);
        final cardBg = isDark
            ? Color.lerp(AppTheme.surfaceDark, AppTheme.cardDark, _shimmer.value)!
            : Colors.white;
        return Container(
          decoration: BoxDecoration(
              color: cardBg, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Expanded(
                flex: 6,
                child: Container(
                    decoration: BoxDecoration(
                        color: c,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(20))))),
            Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            height: 12,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(6))),
                        const SizedBox(height: 8),
                        Container(
                            height: 10,
                            width: 80,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(6))),
                      ]),
                )),
          ]),
        );
      },
    );
  }
}

/// Custom page route with slide transition
class _SlideRoute extends PageRoute {
  final Widget child;
  _SlideRoute({required this.child});

  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return SlideTransition(
      position: Tween<Offset>(
              begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }
}
