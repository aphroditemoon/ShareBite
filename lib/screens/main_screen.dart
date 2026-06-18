import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'home/home_screen.dart';
import 'search/search_screen.dart';
import 'add/add_listing_screen.dart';
import 'map/map_screen.dart';
import 'profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _homeRefreshVersion = 0;

  void _openSearchFromHome() {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = 1);
  }

  void _handleListingCreated() {
    setState(() {
      _currentIndex = 0;
      _homeRefreshVersion++;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Listing published and Home refreshed! 🎉'),
      backgroundColor: AppTheme.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _onTap(int index) {
    if (index == 2) { _showAddMenu(); return; }
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  void _showAddMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMenuSheet(onListingCreated: _handleListingCreated),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onExploreNow: _openSearchFromHome, refreshVersion: _homeRefreshVersion),
      const SearchScreen(),
      const MapScreen(),
      ProfileScreen(refreshVersion: _homeRefreshVersion),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex > 2 ? _currentIndex - 1 : _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    final dark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        gradient: dark
            ? AppTheme.skyGradientDark(begin: Alignment.topCenter, end: Alignment.bottomCenter)
            : AppTheme.skyGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.3 : 0.07),
          blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded,        label: 'Home',    index: 0, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.search_rounded,      label: 'Search',  index: 1, current: _currentIndex, onTap: _onTap),
              Expanded(child: _AnimatedFab(onTap: () => _onTap(2))),
              _NavItem(icon: Icons.map_outlined,        label: 'Map',     index: 3, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', index: 4, current: _currentIndex, onTap: _onTap),
            ],
          ),
        ),
      ),
    );
  }
}


class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final Function(int) onTap;
  const _NavItem({required this.icon, required this.label, required this.index,
      required this.current, required this.onTap});
  @override State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;
  @override void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 120),
        reverseDuration: const Duration(milliseconds: 170));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.86)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }
  @override void dispose() { _pressCtrl.dispose(); super.dispose(); }

  void _tap() {
    widget.onTap(widget.index);
    _pressCtrl.forward().then((_) { if (mounted) _pressCtrl.reverse(); });
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.current == widget.index || (widget.index == 4 && widget.current == 4);
    final unselColor = AppTheme.isDark(context)
        ? AppTheme.textSecondaryDark
        : const Color(0xFF8DA6BA);
    return Expanded(
      child: GestureDetector(
        onTap: _tap,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 230),
            curve: Curves.easeOutBack,
            padding: const EdgeInsets.only(top: 5, bottom: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 230),
                  curve: Curves.easeOutBack,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: sel ? AppTheme.primaryGradient() : null,
                    color: sel ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: sel ? [
                      BoxShadow(color: AppTheme.primary.withOpacity(0.22), blurRadius: 10, offset: const Offset(0, 4)),
                    ] : null,
                  ),
                  child: Icon(widget.icon, color: sel ? Colors.white : unselColor, size: sel ? 24 : 22),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontFamily: 'Nunito', fontSize: sel ? 10.5 : 10,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                    color: sel ? AppTheme.primaryDark : unselColor,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _AnimatedFab extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedFab({required this.onTap});
  @override State<_AnimatedFab> createState() => _AnimatedFabState();
}
class _AnimatedFabState extends State<_AnimatedFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;
  @override void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 120),
        reverseDuration: const Duration(milliseconds: 180));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.84)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }
  @override void dispose() { _pressCtrl.dispose(); super.dispose(); }
  void _tap() {
    widget.onTap();
    _pressCtrl.forward().then((_) { if (mounted) _pressCtrl.reverse(); });
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient(),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _AddMenuSheet extends StatelessWidget {
  final VoidCallback onListingCreated;
  const _AddMenuSheet({required this.onListingCreated});

  static const _items = [
    {'cat': 'free_food',    'icon': Icons.restaurant_outlined,       'title': 'Free Food',     'sub': 'Give away food for free'},
    {'cat': 'free_nonfood', 'icon': Icons.card_giftcard_outlined,    'title': 'Free Non-Food', 'sub': 'Give away items you no longer need'},
    {'cat': 'for_sale',     'icon': Icons.sell_outlined,             'title': 'Sell',          'sub': 'Sell non-food items'},
    {'cat': 'borrow',       'icon': Icons.swap_horiz_rounded,        'title': 'Lend',          'sub': 'Lend your things locally'},
    {'cat': 'wanted',       'icon': Icons.record_voice_over_outlined, 'title': 'Wanted',       'sub': 'Ask for something from the community'},
  ];

  @override
  Widget build(BuildContext context) {
    final sheetColor = AppTheme.sheet(context);
    final txtPrimary  = AppTheme.txtPrimary(context);
    final txtSecondary= AppTheme.txtSecondary(context);
    final handleColor = AppTheme.isDark(context)
        ? Colors.white.withOpacity(0.15)
        : Colors.grey.withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(color: sheetColor, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: handleColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Share something',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 20,
                    fontWeight: FontWeight.w800, color: txtPrimary)),
          ),
          const SizedBox(height: 8),
          ..._items.asMap().entries.map((e) {
            final item = e.value;
            final color = AppTheme.categoryColors[item['cat']]!;
            return _AnimatedMenuTile(
              icon: item['icon'] as IconData,
              title: item['title'] as String,
              sub: item['sub'] as String,
              color: color,
              txtPrimary: txtPrimary,
              txtSecondary: txtSecondary,
              delay: e.key * 40,
              onTap: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                final created = await navigator.push<bool>(MaterialPageRoute(
                    builder: (_) => AddListingScreen(preselectedCategory: item['cat'] as String)));
                if (created == true) onListingCreated();
              },
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _AnimatedMenuTile extends StatefulWidget {
  final IconData icon;
  final String title, sub;
  final Color color, txtPrimary, txtSecondary;
  final int delay;
  final VoidCallback onTap;
  const _AnimatedMenuTile({required this.icon, required this.title, required this.sub,
      required this.color, required this.txtPrimary, required this.txtSecondary,
      required this.delay, required this.onTap});
  @override State<_AnimatedMenuTile> createState() => _AnimatedMenuTileState();
}
class _AnimatedMenuTileState extends State<_AnimatedMenuTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final AnimationController _pressCtrl;
  late final Animation<Color?> _bgColor;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.forward(); });
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 200));
    _bgColor = ColorTween(begin: Colors.transparent, end: widget.color.withOpacity(0.06))
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); _pressCtrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final arrowColor = AppTheme.isDark(context)
        ? AppTheme.textSecondaryDark.withOpacity(0.5)
        : Colors.grey[300]!;
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: AnimatedBuilder(
          animation: _bgColor,
          builder: (_, child) => Container(color: _bgColor.value, child: child),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: widget.color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
            title: Text(widget.title,
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                    fontSize: 15, color: widget.txtPrimary)),
            subtitle: Text(widget.sub,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: widget.txtSecondary)),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: arrowColor),
            onTap: () {
              HapticFeedback.selectionClick();
              _pressCtrl.forward().then((_) => _pressCtrl.reverse());
              widget.onTap();
            },
          ),
        ),
      ),
    );
  }
}
