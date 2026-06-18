import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../models/listing_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_card.dart' show getFallbackImage;
import '../profile/user_profile_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});
  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen>
    with TickerProviderStateMixin {
  ListingModel? _listing;
  Map<String, dynamic>? _mlData;
  bool _loading = true;
  bool _mlLoading = false;
  int _imgIndex = 0;
  bool _isSaved = false;

  // Entrance animations
  late final AnimationController _entranceCtrl;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  // Save button animation
  late final AnimationController _saveCtrl;
  late final Animation<double> _saveScale;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _contentFade = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)));

    _saveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _saveScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 35),
    ]).animate(_saveCtrl);

    _fetchListing();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _saveCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchListing() async {
    try {
      final res = await ApiService.getListing(widget.listingId);
      if (res['success'] == true) {
        if (!mounted) return;
        setState(() {
          _listing = ListingModel.fromJson(res['data']['listing']);
          _loading = false;
        });
        _entranceCtrl.forward();
        _fetchML();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchML() async {
    if (_listing == null) return;
    if (mounted) setState(() => _mlLoading = true);
    try {
      final res = await ApiService.getRecommendations(
        listingId: _listing!.id,
        title: _listing!.title,
        tags: _listing!.tags,
        category: _listing!.category,
        description: _listing!.description,
      );
      if (res['success'] == true && mounted) setState(() => _mlData = res['data']);
    } catch (_) {}
    if (mounted) setState(() => _mlLoading = false);
  }

  void _showRequestSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestSheet(listing: _listing!),
    );
  }

  bool _isLocalImage(String url) => url.startsWith('file://');

  String _localImagePath(String url) {
    if (!url.startsWith('file://')) return url;
    return Uri.parse(url).toFilePath(windows: Platform.isWindows);
  }

  ImageProvider? _avatarProvider(String avatarUrl) {
    if (avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('file://')) {
      return FileImage(File(Uri.parse(avatarUrl).toFilePath(windows: Platform.isWindows)));
    }
    return CachedNetworkImageProvider(avatarUrl);
  }

  Widget _listingImage(String imageUrl, Color color) {
    if (_isLocalImage(imageUrl)) {
      return Image.file(File(_localImagePath(imageUrl)),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(
              color: color.withOpacity(0.1),
              child: Icon(Icons.image_outlined,
                  color: color.withOpacity(0.4), size: 36)));
    }
    return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, __, ___) => Container(
            color: color.withOpacity(0.1),
            child: Icon(Icons.image_outlined,
                color: color.withOpacity(0.4), size: 36)));
  }

  void _openOwnerProfile(ListingOwner? owner) {
    if (owner == null || owner.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Owner profile is not available yet'),
        backgroundColor: AppTheme.secondary,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: owner.id,
          fallbackName: owner.name,
          fallbackAvatar: owner.avatar,
        ),
      ),
    );
  }

  void _showMessageSheet() {
    final owner = _listing?.owner;
    if (owner == null || owner.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Owner chat is not available for this listing'),
        backgroundColor: AppTheme.secondary,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageSheet(listing: _listing!, recipientId: owner.id),
    );
  }

  Map<String, dynamic> _fullRecipe(Map<String, dynamic> raw) {
    final title = (raw['title'] ?? raw['name'] ?? 'Simple Recipe').toString();
    final source =
        '${_listing?.title ?? ''} ${_listing?.tags.join(' ') ?? ''}'.toLowerCase();
    String main = _listing?.title ?? 'main ingredient';
    if (source.contains('banana')) main = 'banana';
    if (source.contains('rice') || source.contains('nasi')) main = 'rice';
    if (source.contains('bread')) main = 'bread';
    if (source.contains('noodle') || source.contains('mie')) main = 'noodles';
    if (source.contains('vegetable') || source.contains('sayur')) main = 'vegetables';
    final ingredients = raw['ingredients'] is List
        ? List<String>.from(raw['ingredients'])
        : <String>[
            main,
            '1 tbsp cooking oil or butter',
            '1 clove garlic or onion',
            'Salt and pepper to taste',
            'Optional topping: egg, herbs, or sauce',
          ];
    final steps = raw['steps'] is List
        ? List<String>.from(raw['steps'])
        : <String>[
            'Check the food freshness and remove anything that does not look safe.',
            'Cut or separate $main into small portions so it cooks evenly.',
            'Heat a pan, add oil or butter, then sauté garlic or onion until fragrant.',
            'Add $main and cook while stirring until warm and evenly mixed.',
            'Season lightly, taste, then serve immediately or pack in a clean container.',
          ];
    return {
      'title': title,
      'difficulty': (raw['difficulty'] ?? 'Easy').toString(),
      'time': (raw['time'] ?? '15-25 min').toString(),
      'ingredients': ingredients,
      'steps': steps,
      'tips': raw['tips'] is List
          ? List<String>.from(raw['tips'])
          : <String>['Use clean utensils, keep portions covered, and do not reheat food more than once.'],
    };
  }

  void _showRecipeSheet(Map<String, dynamic> raw, Color catColor) {
    HapticFeedback.selectionClick();
    final recipe = _fullRecipe(raw);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeSheet(recipe: recipe, color: catColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient()),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          ),
        ),
      );
    }
    if (_listing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Listing not found')),
      );
    }

    final l = _listing!;
    final catColor = AppTheme.categoryColors[l.category] ?? AppTheme.primary;
    final isOwner = context.watch<AuthProvider>().user?.id == l.owner?.id;
    final imageUrl =
        l.firstImageUrl.isNotEmpty ? l.firstImageUrl : getFallbackImage(l);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: CustomScrollView(
        slivers: [
          // Collapsible image header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.surface(context),
            leading: _CircleBackButton(),
            actions: [
              // Animated save button
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: AnimatedBuilder(
                  animation: _saveScale,
                  builder: (_, __) => Transform.scale(
                    scale: _saveScale.value,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isSaved = !_isSaved);
                        _saveCtrl.forward(from: 0);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(_isSaved ? 'Saved to favorites!' : 'Removed from favorites'),
                          backgroundColor: _isSaved ? AppTheme.primary : AppTheme.txtSecondary(context),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          margin: const EdgeInsets.all(16),
                          duration: const Duration(seconds: 2),
                        ));
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: AppTheme.surface(context),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8)
                            ]),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            key: ValueKey(_isSaved),
                            color: _isSaved ? AppTheme.primary : AppTheme.txtSecondary(context),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _listingImage(imageUrl, catColor),
                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Image page dots if multiple images
                  if (l.images.length > 1)
                    Positioned(
                      bottom: 14,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          l.images.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _imgIndex == i ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _imgIndex == i
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Body content
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _contentSlide,
              child: FadeTransition(
                opacity: _contentFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category + time
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                              color: catColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                              AppTheme.categoryLabels[l.category] ?? l.category,
                              style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: catColor)),
                        ),
                        const Spacer(),
                        Text(timeago.format(l.createdAt),
                            style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                color: AppTheme.txtSecondary(context))),
                      ]),

                      const SizedBox(height: 12),
                      Text(l.title,
                          style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.txtPrimary(context),
                              height: 1.2)),
                      const SizedBox(height: 10),
                      Row(children: [
                        // Animated price badge
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (_, v, child) =>
                              Transform.scale(scale: v, child: child),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                                color:
                                    l.isFree ? catColor : AppTheme.secondary,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              l.isFree
                                  ? 'FREE'
                                  : 'Rp ${l.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        if (l.quantity > 1) ...[
                          const SizedBox(width: 10),
                          Text('${l.quantity} ${l.unit} available',
                              style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 13,
                                  color: AppTheme.txtSecondary(context))),
                        ],
                      ]),

                      const SizedBox(height: 20),
                      _buildOwnerCard(l),
                      const SizedBox(height: 16),

                      _infoRow(Icons.location_on_outlined, catColor,
                          l.distanceText.isNotEmpty
                              ? '${l.distanceText} away'
                              : 'Location not set',
                          sub: l.location.address.isNotEmpty
                              ? l.location.address
                              : null),

                      if (l.expiresAt != null) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.schedule_rounded, Colors.orange,
                            'Expires ${timeago.format(l.expiresAt!)}'),
                      ],

                      if (l.description.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('About this item',
                            style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.txtPrimary(context))),
                        const SizedBox(height: 8),
                        _ExpandableText(text: l.description),
                      ],

                      if (l.tags.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: l.tags
                              .map((t) => _AnimatedTag(tag: t))
                              .toList(),
                        ),
                      ],

                      if (l.dietaryInfo.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _sectionTitle('Dietary info'),
                        const SizedBox(height: 10),
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: l.dietaryInfo
                                .map((d) => _chip(d, AppTheme.teal))
                                .toList()),
                      ],

                      if (l.allergens.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _sectionTitle('Allergens'),
                        const SizedBox(height: 10),
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: l.allergens
                                .map((a) => _chip(a, AppTheme.secondary))
                                .toList()),
                      ],

                      // ML Section
                      _buildMLSection(catColor),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: isOwner ? null : _buildBottomBar(l, catColor),
    );
  }

  Widget _buildOwnerCard(ListingModel l) {
    return _PressableCard(
      onTap: () => _openOwnerProfile(l.owner),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.div(context)),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primary.withOpacity(0.12),
            backgroundImage: _avatarProvider(l.owner?.avatarUrl ?? ''),
            child: l.owner?.avatarUrl.isNotEmpty != true
                ? Text(
                    (l.owner?.name.isNotEmpty == true
                        ? l.owner!.name.substring(0, 1).toUpperCase()
                        : '?'),
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.owner?.name ?? 'Unknown',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.txtPrimary(context))),
            Text('${l.owner?.stats?.totalShared ?? 0} items shared',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: AppTheme.txtSecondary(context))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary),
                borderRadius: BorderRadius.circular(12)),
            child: Text('View profile',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary)),
          ),
        ]),
      ),
    );
  }

  Widget _buildMLSection(Color catColor) {
    if (_mlLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: catColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: catColor.withOpacity(0.2)),
        ),
        child: Row(children: [
          _PulsingDot(color: catColor),
          const SizedBox(width: 12),
          Text('AI is thinking of recipe ideas...',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: catColor,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }
    if (_mlData == null) return const SizedBox();

    final recipesRaw = (_mlData!['recipes'] as List?) ?? [];
    final recipes = recipesRaw
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final ideasRaw = (_mlData!['cookingIdeas'] as List?) ?? [];
    final ideas = ideasRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final similar = (_mlData!['similarListings'] as List?) ?? [];
    final tipsRaw = (_mlData!['tips'] as List?) ?? [];
    final tips = tipsRaw
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (tips.isNotEmpty) ...[
        const SizedBox(height: 20),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (_, v, child) =>
              Opacity(opacity: v, child: child),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context) ? const Color(0xFF2A2010) : const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE0A0)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xFFFFB300), size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(tips.first,
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w500))),
            ]),
          ),
        ),
      ],

      if (ideas.isNotEmpty) ...[
        const SizedBox(height: 24),
        _sectionTitle('Cooking ideas from AI'),
        const SizedBox(height: 12),
        ...ideas.asMap().entries.map((e) => _AnimatedIdeaCard(
              idea: e.value,
              index: e.key,
              catColor: catColor,
              onTap: () => _showRecipeSheet(e.value, catColor),
            )),
      ],

      if (recipes.isNotEmpty) ...[
        const SizedBox(height: 20),
        _sectionTitle('Suggested recipes'),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recipes
                .map((r) => _PressableRecipeChip(
                      label: r,
                      color: catColor,
                      onTap: () => _showRecipeSheet(
                          {'title': r, 'difficulty': 'Easy', 'time': '15-25 min'},
                          catColor),
                    ))
                .toList()),
      ],

      if (similar.isNotEmpty) ...[
        const SizedBox(height: 24),
        _sectionTitle('Similar listings'),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: similar.length,
            itemBuilder: (_, i) {
              final item = ListingModel.fromJson(similar[i]);
              final c = AppTheme.categoryColors[item.category] ?? AppTheme.primary;
              final img = item.firstImageUrl.isNotEmpty
                  ? item.firstImageUrl
                  : getFallbackImage(item);
              return _PressableCard(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ListingDetailScreen(listingId: item.id)),
                ),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      color: AppTheme.card(context),
                      borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Expanded(child: _listingImage(img, c)),
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(item.title,
                            style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.txtPrimary(context)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    ]);
  }

  Widget _infoRow(IconData icon, Color color, String text, {String? sub}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 12),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Text(text,
            style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.txtPrimary(context))),
        if (sub != null)
          Text(sub,
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: AppTheme.txtSecondary(context))),
      ])),
    ]);
  }

  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.txtPrimary(context)));

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      );

  Widget? _buildBottomBar(ListingModel l, Color catColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
          color: AppTheme.surface(context),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, -4))
          ]),
      child: Row(children: [
        _PressableCard(
          onTap: _showMessageSheet,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.chat_bubble_outline_rounded,
                color: AppTheme.primary, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _GradientActionButton(
          label: l.isFree ? 'Request this item' : 'Buy now',
          color: catColor,
          onTap: _showRequestSheet,
        )),
      ]),
    );
  }
}

/// Circular back button
class _CircleBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
            ],
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: AppTheme.txtPrimary(context)),
        ),
      ),
    );
  }
}

/// Generic pressable wrapper
class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressableCard({required this.child, this.onTap});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.selectionClick(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap?.call(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Gradient CTA button with ripple
class _GradientActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GradientActionButton({required this.label, required this.color, required this.onTap});

  @override
  State<_GradientActionButton> createState() => _GradientActionButtonState();
}

class _GradientActionButtonState extends State<_GradientActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110),
        reverseDuration: const Duration(milliseconds: 180));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.mediumImpact(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: AppTheme.gradientFor(widget.color),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: widget.color.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Center(
            child: Text(widget.label,
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

/// Animated AI idea card
class _AnimatedIdeaCard extends StatefulWidget {
  final Map<String, dynamic> idea;
  final int index;
  final Color catColor;
  final VoidCallback onTap;
  const _AnimatedIdeaCard({required this.idea, required this.index, required this.catColor, required this.onTap});

  @override
  State<_AnimatedIdeaCard> createState() => _AnimatedIdeaCardState();
}

class _AnimatedIdeaCardState extends State<_AnimatedIdeaCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: _PressableCard(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.div(context)),
            ),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.restaurant_outlined,
                      color: AppTheme.primary, size: 22)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((widget.idea['title'] ?? 'Recipe idea').toString(),
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.txtPrimary(context))),
                const SizedBox(height: 2),
                Text(
                    '${widget.idea['difficulty'] ?? 'Easy'} • ${widget.idea['time'] ?? '15-25 min'}',
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: AppTheme.txtSecondary(context))),
              ])),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('View recipe',
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Pressable recipe chip
class _PressableRecipeChip extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PressableRecipeChip({required this.label, required this.color, required this.onTap});

  @override
  State<_PressableRecipeChip> createState() => _PressableRecipeChipState();
}

class _PressableRecipeChipState extends State<_PressableRecipeChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.selectionClick(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.color.withOpacity(0.3)),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.color)),
        ),
      ),
    );
  }
}

/// Animated hashtag
class _AnimatedTag extends StatefulWidget {
  final String tag;
  const _AnimatedTag({required this.tag});

  @override
  State<_AnimatedTag> createState() => _AnimatedTagState();
}

class _AnimatedTagState extends State<_AnimatedTag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.90)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: AppTheme.inputFill2(context),
              borderRadius: BorderRadius.circular(20)),
          child: Text('#${widget.tag}',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: AppTheme.txtSecondary(context),
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// Expandable description text
class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final needsExpand = widget.text.length > 200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: Text(
            widget.text,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppTheme.txtSecondary(context), height: 1.6),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          secondChild: Text(
            widget.text,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppTheme.txtSecondary(context), height: 1.6),
          ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        if (needsExpand)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? 'Show less' : 'Read more',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pulsing dot for AI loading state
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── Bottom Sheets ────────────────────────────────────────────────────────────

class _RecipeSheet extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final Color color;
  const _RecipeSheet({required this.recipe, required this.color});

  @override
  Widget build(BuildContext context) {
    final ingredients = List<String>.from(recipe['ingredients'] ?? []);
    final steps = List<String>.from(recipe['steps'] ?? []);
    final tips = List<String>.from(recipe['tips'] ?? []);
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppTheme.sheet(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.restaurant_menu_rounded, color: color, size: 24)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(recipe['title'].toString(),
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.txtPrimary(context))),
                const SizedBox(height: 3),
                Text('${recipe['difficulty']} • ${recipe['time']}',
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: AppTheme.txtSecondary(context))),
              ])),
            ]),
            const SizedBox(height: 22),
            _title(context, 'Ingredients'),
            const SizedBox(height: 10),
            ...ingredients.map((i) => _bullet(context, i)),
            const SizedBox(height: 18),
            _title(context, 'Steps'),
            const SizedBox(height: 10),
            ...List.generate(steps.length, (i) => _step(context, i + 1, steps[i], color)),
            if (tips.isNotEmpty) ...[
              const SizedBox(height: 18),
              _title(context, 'Safety tips'),
              const SizedBox(height: 10),
              ...tips.map((t) => _bullet(context, t)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String text) => Text(text,
      style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppTheme.txtPrimary(context)));

  Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('•  ',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: AppTheme.txtPrimary(context))),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      height: 1.45,
                      color: AppTheme.txtSecondary(context)))),
        ]),
      );

  Widget _step(BuildContext context, int no, String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Center(
                  child: Text('$no',
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color)))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      height: 1.45,
                      color: AppTheme.txtSecondary(context)))),
        ]),
      );
}

class _MessageSheet extends StatefulWidget {
  final ListingModel listing;
  final String recipientId;
  const _MessageSheet({required this.listing, required this.recipientId});

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  late final TextEditingController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: 'Hi, is "${widget.listing.title}" still available?');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.sendMessage(widget.recipientId, text,
          listingId: widget.listing.id);
      if (res['success'] == true && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(
          content: Text('Message sent! ✉️'),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.secondary,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
          color: AppTheme.sheet(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Message owner',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.txtPrimary(context))),
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                maxLines: 4,
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: AppTheme.txtPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  filled: true,
                  fillColor: AppTheme.inputFill2(context),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              _GradientActionButton(
                label: 'Send message',
                color: AppTheme.primary,
                onTap: _loading ? () {} : _send,
              ),
            ]),
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  final ListingModel listing;
  const _RequestSheet({required this.listing});
  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _msgCtrl = TextEditingController();
  int _qty = 1;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.createRequest(widget.listing.id,
          message: _msgCtrl.text, quantity: _qty);
      if (res['success'] == true && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(
          content: Text('Request sent successfully! 🎉'),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.secondary,
            behavior: SnackBarBehavior.floating));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
          color: AppTheme.sheet(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Send a request',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.txtPrimary(context))),
              const SizedBox(height: 16),

              if (widget.listing.quantity > 1) ...[
                Text('Quantity',
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.txtPrimary(context))),
                const SizedBox(height: 8),
                Row(children: [
                  _AnimatedQtyBtn(
                    icon: Icons.remove_rounded,
                    onTap: () {
                      if (_qty > 1) setState(() => _qty--);
                    },
                  ),
                  const SizedBox(width: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim, child: child),
                    child: Text('$_qty',
                        key: ValueKey(_qty),
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 20),
                  _AnimatedQtyBtn(
                    icon: Icons.add_rounded,
                    onTap: () {
                      if (_qty < widget.listing.quantity)
                        setState(() => _qty++);
                    },
                  ),
                ]),
                const SizedBox(height: 16),
              ],

              Text('Message (optional)',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.txtPrimary(context))),
              const SizedBox(height: 8),
              TextField(
                  controller: _msgCtrl,
                  maxLines: 3,
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      color: AppTheme.txtPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'Hi, I would love to have this!',
                    hintStyle: TextStyle(
                        fontFamily: 'Nunito',
                        color: AppTheme.txtSecondary(context).withOpacity(0.7),
                        fontSize: 14),
                    filled: true,
                    fillColor: AppTheme.inputFill2(context),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppTheme.primary, width: 1.5)),
                  )),
              const SizedBox(height: 20),
              _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary, strokeWidth: 2.5))
                  : _GradientActionButton(
                      label: 'Send request',
                      color: AppTheme.primary,
                      onTap: _submit,
                    ),
            ]),
      ),
    );
  }
}

class _AnimatedQtyBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AnimatedQtyBtn({required this.icon, required this.onTap});

  @override
  State<_AnimatedQtyBtn> createState() => _AnimatedQtyBtnState();
}

class _AnimatedQtyBtnState extends State<_AnimatedQtyBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80),
        reverseDuration: const Duration(milliseconds: 130));
    _scale = Tween<double>(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.selectionClick(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(widget.icon, color: AppTheme.primary, size: 18)),
      ),
    );
  }
}
