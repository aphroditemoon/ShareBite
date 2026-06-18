import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../models/listing_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/animated_category_chip.dart';
import '../listing/listing_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _focus = FocusNode();
  List<ListingModel> _results = [];
  bool _loading = false;
  bool _searched = false;
  String _selectedCategory = 'all';
  Position? _position;

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  final _categories = [
    {'id': 'all', 'label': 'All'},
    {'id': 'free_food', 'label': 'Free Food'},
    {'id': 'free_nonfood', 'label': 'Free Non-Food'},
    {'id': 'for_sale', 'label': 'For Sale'},
    {'id': 'borrow', 'label': 'Borrow'},
    {'id': 'wanted', 'label': 'Wanted'},
  ];

  final _popular = [
    'Rice box', 'Cake', 'Vegetables', 'Fruit', 'Books', 'Clothes', 'Plants', 'Noodles',
  ];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
    _getLocation();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _searchCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.deniedForever) {
        _position = await Geolocator.getCurrentPosition();
      }
    } catch (_) {}
  }

  Future<void> _search([String? q]) async {
    final query = q ?? _searchCtrl.text.trim();
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() { _loading = true; _searched = true; });
    try {
      final res = await ApiService.getListings(
        lat: _position?.latitude, lng: _position?.longitude,
        category: _selectedCategory, search: query, radius: 100000, sort: 'newest',
      );
      if (res['success'] == true) {
        final data = res['data']['listings'] as List;
        if (!mounted) return;
        setState(() => _results = data.map((e) => ListingModel.fromJson(e)).toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            SlideTransition(
              position: _entrySlide,
              child: FadeTransition(
                opacity: _entryFade,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.skyGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    children: [
                      // Animated search bar
                      _AnimatedSearchBar(
                        controller: _searchCtrl,
                        focusNode: _focus,
                        onSubmitted: _search,
                        onChanged: (v) => setState(() {}),
                        onClear: () {
                          _searchCtrl.clear();
                          setState(() { _searched = false; _results = []; });
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          itemBuilder: (_, i) {
                            final cat = _categories[i];
                            final sel = _selectedCategory == cat['id'];
                            final color = i == 0
                                ? AppTheme.primary
                                : (AppTheme.categoryColors[cat['id']] ?? AppTheme.primary);
                            return AnimatedCategoryChip(
                              label: cat['label']!,
                              selected: sel,
                              color: color,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              radius: 20,
                              fontSize: 12,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedCategory = cat['id']!);
                                if (_searched) _search();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _loading
                    ? _buildLoadingState()
                    : !_searched
                        ? _buildDiscovery()
                        : _results.isEmpty
                            ? _buildEmpty()
                            : _buildResults(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
        const SizedBox(height: 16),
        Text('Searching...', style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
            color: AppTheme.txtSecondary(context), fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildDiscovery() {
    return SingleChildScrollView(
      key: const ValueKey('discovery'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trending',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
                  fontWeight: FontWeight.w800, color: AppTheme.txtPrimary(context))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popular.asMap().entries.map((e) {
              return _TrendingChip(
                label: e.value,
                index: e.key,
                onTap: () {
                  _searchCtrl.text = e.value;
                  _search(e.value);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Text('Browse by category',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
                  fontWeight: FontWeight.w800, color: AppTheme.txtPrimary(context))),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: AppTheme.categoryColors.entries.toList().asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final label = AppTheme.categoryLabels[e.key] ?? e.key;
              return _AnimatedCategoryCard(
                index: i,
                label: label,
                color: e.value,
                onTap: () {
                  setState(() => _selectedCategory = e.key);
                  _search();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      key: const ValueKey('results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text('${_results.length} results',
                key: ValueKey(_results.length),
                style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                    fontWeight: FontWeight.w700, color: AppTheme.txtPrimary(context))),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _results.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 0.70,
                crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemBuilder: (_, i) {
              return TweenAnimationBuilder<double>(
                key: ValueKey(_results[i].id),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + i * 50),
                curve: Curves.easeOut,
                builder: (_, v, child) => Opacity(opacity: v,
                    child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child)),
                child: ListingCard(
                  listing: _results[i],
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: _results[i].id))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      key: const ValueKey('empty'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.search_off_rounded, color: AppTheme.primary, size: 36)),
        ),
        const SizedBox(height: 20),
        Text('No results for "${_searchCtrl.text}"',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                fontWeight: FontWeight.w800, color: AppTheme.txtPrimary(context)),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Try different keywords or a wider radius',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppTheme.txtSecondary(context))),
      ]),
    );
  }
}

/// Animated search bar with focus ring
class _AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onSubmitted;
  final void Function(String) onChanged;
  final VoidCallback onClear;

  const _AnimatedSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _borderAnim;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _borderAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    widget.focusNode.addListener(() {
      setState(() => _focused = widget.focusNode.hasFocus);
      if (widget.focusNode.hasFocus) _ctrl.forward();
      else _ctrl.reverse();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _borderAnim,
      builder: (context, __) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color.lerp(AppTheme.divider, AppTheme.primary, _borderAnim.value)!,
            width: _focused ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08 * _borderAnim.value),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
              fontWeight: FontWeight.w600, color: AppTheme.txtPrimary(context)),
          decoration: InputDecoration(
            hintText: 'Search for food and items...',
            hintStyle: TextStyle(fontFamily: 'Nunito', color: AppTheme.txtSecondary(context), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary, size: 22),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.txtSecondary(context)),
                    onPressed: widget.onClear)
                : null,
            filled: false,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

/// Animated trending chip
class _TrendingChip extends StatefulWidget {
  final String label;
  final int index;
  final VoidCallback onTap;
  const _TrendingChip({required this.label, required this.index, required this.onTap});

  @override
  State<_TrendingChip> createState() => _TrendingChipState();
}

class _TrendingChipState extends State<_TrendingChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _entered ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTapDown: (_) { HapticFeedback.selectionClick(); _pressCtrl.forward(); },
        onTapUp: (_) { _pressCtrl.reverse(); widget.onTap(); },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.div(context)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Text(widget.label,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                    fontWeight: FontWeight.w600, color: AppTheme.txtPrimary(context))),
          ),
        ),
      ),
    );
  }
}

/// Animated category browse card
class _AnimatedCategoryCard extends StatefulWidget {
  final int index;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AnimatedCategoryCard({required this.index, required this.label, required this.color, required this.onTap});

  @override
  State<_AnimatedCategoryCard> createState() => _AnimatedCategoryCardState();
}

class _AnimatedCategoryCardState extends State<_AnimatedCategoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.selectionClick(); _pressCtrl.forward(); },
      onTapUp: (_) { _pressCtrl.reverse(); widget.onTap(); },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: widget.color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.restaurant_outlined, color: widget.color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      fontWeight: FontWeight.w700, color: widget.color)),
            ),
          ]),
        ),
      ),
    );
  }
}
