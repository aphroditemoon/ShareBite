import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/theme_provider.dart';
import '../../models/listing_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_card.dart';
import '../listing/listing_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int refreshVersion;
  const ProfileScreen({super.key, this.refreshVersion = 0});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  List<ListingModel> _myListings = [];
  bool _listingsLoading = true;

  late final AnimationController _headerEntryCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _headerEntryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade = CurvedAnimation(parent: _headerEntryCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerEntryCtrl, curve: Curves.easeOutCubic));
    _headerEntryCtrl.forward();
    _fetchMyListings();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshVersion != oldWidget.refreshVersion) {
      _fetchMyListings();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _headerEntryCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMyListings() async {
    if (mounted) setState(() => _listingsLoading = true);
    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) {
        if (mounted) setState(() => _myListings = []);
        return;
      }
      final res = await ApiService.getListings();
      if (res['success'] == true) {
        final data = res['data']['listings'] as List;
        if (mounted) {
          setState(() {
            _myListings = data
                .map((e) => ListingModel.fromJson(e))
                .where((l) => l.owner?.id == userId)
                .toList();
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _listingsLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: _buildHeader(user),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBar(
              TabBar(
                controller: _tabCtrl,
                tabs: [Tab(text: 'My listings'), Tab(text: 'My impact')],
                labelStyle: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: TextStyle(fontFamily: 'Nunito', fontSize: 14),
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.txtSecondary(context),
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2.5,
                dividerColor: AppTheme.div(context),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [_buildMyListings(), _buildImpact(user)],
        ),
      ),
    );
  }

  ImageProvider? _avatarProvider(String avatarUrl) {
    if (avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('file://')) {
      return FileImage(File(Uri.parse(avatarUrl).toFilePath(windows: Platform.isWindows)));
    }
    return CachedNetworkImageProvider(avatarUrl);
  }

  Widget _buildHeader(UserModel? user) {
    return Container(
      color: AppTheme.surface(context),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              // Animated avatar
              _AnimatedAvatarButton(
                user: user,
                avatarProvider: _avatarProvider(user?.avatarUrl ?? ''),
                onTap: () => _showAvatarPicker(user),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(user?.name ?? '',
                          style: TextStyle(fontFamily: 'Nunito', fontSize: 20,
                              fontWeight: FontWeight.w800, color: AppTheme.txtPrimary(context)),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (user?.isVerified == true)
                      Icon(Icons.verified_rounded, color: AppTheme.primary, size: 18),
                  ]),
                  const SizedBox(height: 2),
                  Text(user?.email ?? '',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppTheme.txtSecondary(context)),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
              // Animated settings button
              _PressIconButton(
                icon: Icons.settings_outlined,
                onTap: _showSettings,
                backgroundColor: AppTheme.inputFill2(context),
                iconColor: AppTheme.primary,
              ),
            ],
          ),

          if (user?.bio.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(user!.bio,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                      color: AppTheme.txtSecondary(context), height: 1.5)),
            ),
          ],

          const SizedBox(height: 20),
          // Animated stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.primary.withOpacity(AppTheme.isDark(context) ? 0.18 : 0.08),
                AppTheme.primary.withOpacity(AppTheme.isDark(context) ? 0.10 : 0.04),
              ]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _AnimatedStatItem(value: '${user?.stats.totalShared ?? 0}', label: 'Shared', delay: 100),
                Container(width: 1, height: 36, color: AppTheme.div(context)),
                _AnimatedStatItem(value: '${user?.stats.totalReceived ?? 0}', label: 'Received', delay: 200),
                Container(width: 1, height: 36, color: AppTheme.div(context)),
                _AnimatedStatItem(value: '${user?.stats.mealsaved ?? 0}', label: 'Meals saved', delay: 300),
              ],
            ),
          ),

          // Edit profile button
          const SizedBox(height: 14),
          _EditProfileButton(onTap: () => _showEditProfile(user)),
        ],
      ),
    );
  }

  Widget _buildMyListings() {
    if (_listingsLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_myListings.isEmpty) {
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(opacity: v,
              child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(width: 72, height: 72,
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(AppTheme.isDark(context) ? 0.2 : 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 36)),
            ),
            const SizedBox(height: 20),
            Text("You haven't shared anything yet",
                style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                    fontWeight: FontWeight.w800, color: AppTheme.txtPrimary(context))),
            const SizedBox(height: 8),
            Text('Start sharing by tapping the + button',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppTheme.txtSecondary(context))),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchMyListings,
      color: AppTheme.primary,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _myListings.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.70,
            crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemBuilder: (_, i) {
          return TweenAnimationBuilder<double>(
            key: ValueKey(_myListings[i].id),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + i * 60),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v,
                child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
            child: ListingCard(
              listing: _myListings[i],
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: _myListings[i].id))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImpact(UserModel? user) {
    final mealsaved = user?.stats.mealsaved ?? 0;
    final shared = user?.stats.totalShared ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
      children: [
        // Hero impact card
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(opacity: v,
              child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Your impact on the world",
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                      fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text('You have helped save $mealsaved meals from going to waste.',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                      color: Colors.white70, height: 1.5)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _AnimatedImpactTile(index: 0, icon: Icons.restaurant_outlined, color: AppTheme.teal, label: 'Meals saved', value: '$mealsaved portions'),
        _AnimatedImpactTile(index: 1, icon: Icons.people_outline_rounded, color: AppTheme.primary, label: 'People helped', value: '${user?.stats.totalReceived ?? 0} people'),
        _AnimatedImpactTile(index: 2, icon: Icons.card_giftcard_outlined, color: AppTheme.accent, label: 'Items shared', value: '$shared items'),
        _AnimatedImpactTile(index: 3, icon: Icons.water_drop_outlined, color: const Color(0xFF29B6F6), label: 'Water saved', value: '${mealsaved * 50} litres'),
        _AnimatedImpactTile(index: 4, icon: Icons.eco_outlined, color: AppTheme.green, label: 'CO2 reduced', value: '${(mealsaved * 0.5).toStringAsFixed(1)} kg'),
        const SizedBox(height: 20),
        Text('Badges',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
                fontWeight: FontWeight.w800, color: AppTheme.txtPrimary(context))),
        const SizedBox(height: 12),
        if (user?.badges.isNotEmpty == true)
          Wrap(
            spacing: 10, runSpacing: 10,
            children: user!.badges.asMap().entries.map((e) => _AnimatedBadge(
              label: e.value, index: e.key,
            )).toList(),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.card(context), borderRadius: BorderRadius.circular(16)),
            child: Text('Complete your first share to earn badges!',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppTheme.txtSecondary(context))),
          ),
      ],
    );
  }

  void _showAvatarPicker(UserModel? user) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        decoration: BoxDecoration(color: AppTheme.sheet(context), borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Change photo',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.txtPrimary(context))),
          const SizedBox(height: 16),
          _sheetTile(Icons.camera_alt_outlined, 'Take a photo', () async {
            Navigator.pop(context);
            final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
            if (file != null && mounted) _uploadAvatar(File(file.path));
          }),
          _sheetTile(Icons.photo_library_outlined, 'Choose from gallery', () async {
            Navigator.pop(context);
            final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
            if (file != null && mounted) _uploadAvatar(File(file.path));
          }),
        ]),
      ),
    );
  }

  Future<void> _uploadAvatar(File avatar) async {
    try {
      final res = await ApiService.updateProfile({}, avatar: avatar);
      if (res['success'] == true && mounted) {
        final auth = context.read<AuthProvider>();
        final data = res['data'];
        if (data is Map && data['user'] != null) {
          auth.updateUser(UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map)));
        } else {
          final me = await ApiService.getMe();
          if (me['success'] == true) auth.updateUser(UserModel.fromJson(me['data']['user']));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile picture updated! 📸'),
            backgroundColor: AppTheme.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.secondary));
    }
  }

  void _showEditProfile(UserModel? user) {
    final nameCtrl = TextEditingController(text: user?.name);
    final bioCtrl = TextEditingController(text: user?.bio);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          decoration: BoxDecoration(color: AppTheme.sheet(context), borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Edit profile',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.txtPrimary(context))),
                const SizedBox(height: 20),
                Text('Name', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.txtPrimary(context))),
                const SizedBox(height: 8),
                TextFormField(controller: nameCtrl,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.txtPrimary(context)),
                    decoration: _deco('Your name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                Text('Bio', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.txtPrimary(context))),
                const SizedBox(height: 8),
                TextFormField(controller: bioCtrl, maxLines: 3,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 15, color: AppTheme.txtPrimary(context)),
                    decoration: _deco('Tell us about yourself...')),
                const SizedBox(height: 20),
                _SheetActionButton(
                  label: 'Save changes',
                  onTap: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    try {
                      final res = await ApiService.updateProfile({'name': nameCtrl.text, 'bio': bioCtrl.text});
                      if (res['success'] == true && mounted) {
                        final auth = context.read<AuthProvider>();
                        final data = res['data'];
                        if (data is Map && data['user'] != null) {
                          auth.updateUser(UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map)));
                        } else {
                          final me = await ApiService.getMe();
                          if (me['success'] == true) auth.updateUser(UserModel.fromJson(me['data']['user']));
                        }
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Profile updated! ✅'),
                          backgroundColor: AppTheme.green,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.secondary));
                    }
                  },
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontFamily: 'Nunito', color: AppTheme.txtSecondary(context).withOpacity(0.6), fontSize: 14),
    filled: true, fillColor: AppTheme.inputFill2(context),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  void _showInfoSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSettings() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) {
          final themeProvider = ctx2.watch<ThemeProvider>();
          final isDark = themeProvider.isDark;
          final handleColor = isDark ? Colors.white.withOpacity(0.15) : Colors.grey.withOpacity(0.3);
          final sheetColor = isDark ? AppTheme.sheetDark : Colors.white;
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            decoration: BoxDecoration(color: sheetColor, borderRadius: BorderRadius.circular(24)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: handleColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              _sheetTile(Icons.person_outline_rounded, 'Edit profile',
                  () { Navigator.pop(context); _showEditProfile(context.read<AuthProvider>().user); }),
              // ── Dark mode toggle ──────────────────────────────────────────
              _DarkModeToggleTile(
                isDark: themeProvider.isDark,
                onToggle: () async {
                  await themeProvider.toggle();
                  setSt(() {}); // refresh sheet icon
                },
              ),
              _sheetTile(Icons.notifications_outlined, 'Notifications',
                  () { Navigator.pop(context); _showInfoSnack('No new notifications right now.'); }),
              _sheetTile(Icons.lock_outline_rounded, 'Privacy & security',
                  () { Navigator.pop(context); _showInfoSnack('Your profile uses secure login storage on this device.'); }),
              _sheetTile(Icons.help_outline_rounded, 'Help & support',
                  () { Navigator.pop(context); _showInfoSnack('Need help? Try refreshing, relogging in, or restarting the backend.'); }),
              const Divider(height: 1, indent: 20, endIndent: 20),
              _sheetTile(Icons.logout_rounded, 'Sign out', () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().logout();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              }, color: AppTheme.secondary),
              const SizedBox(height: 8),
            ]),
          );
        },
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final isDark = context.read<ThemeProvider>().isDark;
    final c = color ?? (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary);
    return _AnimatedListTile(icon: icon, label: label, color: c, onTap: onTap);
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _AnimatedAvatarButton extends StatefulWidget {
  final UserModel? user;
  final ImageProvider? avatarProvider;
  final VoidCallback onTap;
  const _AnimatedAvatarButton({this.user, this.avatarProvider, required this.onTap});
  @override State<_AnimatedAvatarButton> createState() => _AnimatedAvatarButtonState();
}
class _AnimatedAvatarButtonState extends State<_AnimatedAvatarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final user = widget.user;
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.lightImpact(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Stack(children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: AppTheme.primary.withOpacity(0.12),
            backgroundImage: widget.avatarProvider,
            child: user?.avatarUrl.isNotEmpty != true
                ? Text(
                    user?.name.isNotEmpty == true
                        ? user!.name.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 28,
                        fontWeight: FontWeight.w800, color: AppTheme.primary))
                : null,
          ),
          Positioned(bottom: 0, right: 0,
            child: Container(width: 24, height: 24,
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              child: Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white))),
        ]),
      ),
    );
  }
}

class _PressIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;
  const _PressIconButton({required this.icon, required this.onTap, required this.backgroundColor, required this.iconColor});
  @override State<_PressIconButton> createState() => _PressIconButtonState();
}
class _PressIconButtonState extends State<_PressIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 90),
        reverseDuration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.lightImpact(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: widget.backgroundColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(widget.icon, color: widget.iconColor, size: 20),
        ),
      ),
    );
  }
}

class _AnimatedStatItem extends StatefulWidget {
  final String value;
  final String label;
  final int delay;
  const _AnimatedStatItem({required this.value, required this.label, required this.delay});
  @override State<_AnimatedStatItem> createState() => _AnimatedStatItemState();
}
class _AnimatedStatItemState extends State<_AnimatedStatItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.forward(); });
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Expanded(
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Column(children: [
            Text(widget.value,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 20,
                    fontWeight: FontWeight.w800, color: AppTheme.primary)),
            const SizedBox(height: 2),
            Text(widget.label,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                    color: AppTheme.txtSecondary(context), fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _EditProfileButton extends StatefulWidget {
  final VoidCallback onTap;
  const _EditProfileButton({required this.onTap});
  @override State<_EditProfileButton> createState() => _EditProfileButtonState();
}
class _EditProfileButtonState extends State<_EditProfileButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.lightImpact(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null, // handled by GestureDetector above
            icon: Icon(Icons.edit_outlined, size: 16),
            label: Text('Edit profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedImpactTile extends StatefulWidget {
  final int index;
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _AnimatedImpactTile({required this.index, required this.icon, required this.color, required this.label, required this.value});
  @override State<_AnimatedImpactTile> createState() => _AnimatedImpactTileState();
}
class _AnimatedImpactTileState extends State<_AnimatedImpactTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 80), () { if (mounted) _ctrl.forward(); });
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.card(context), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(width: 44, height: 44,
                decoration: BoxDecoration(color: widget.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(widget.icon, color: widget.color, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Text(widget.label,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                    fontWeight: FontWeight.w600, color: AppTheme.txtPrimary(context)))),
            Text(widget.value,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                    fontWeight: FontWeight.w800, color: widget.color)),
          ]),
        ),
      ),
    );
  }
}

class _AnimatedBadge extends StatefulWidget {
  final String label;
  final int index;
  const _AnimatedBadge({required this.label, required this.index});
  @override State<_AnimatedBadge> createState() => _AnimatedBadgeState();
}
class _AnimatedBadgeState extends State<_AnimatedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    Future.delayed(Duration(milliseconds: widget.index * 70), () { if (mounted) _ctrl.forward(); });
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
        ),
        child: Text(widget.label,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                fontWeight: FontWeight.w700, color: Color(0xFFD4A000))),
      ),
    );
  }
}

class _AnimatedListTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AnimatedListTile({required this.icon, required this.label, required this.color, required this.onTap});
  @override State<_AnimatedListTile> createState() => _AnimatedListTileState();
}
class _AnimatedListTileState extends State<_AnimatedListTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<Color?> _bgColor;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 200));
    _bgColor = ColorTween(begin: Colors.transparent, end: widget.color.withOpacity(0.05))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void didUpdateWidget(covariant _AnimatedListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _bgColor = ColorTween(begin: Colors.transparent, end: widget.color.withOpacity(0.05))
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    }
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgColor,
      builder: (_, child) => Container(color: _bgColor.value, child: child),
      child: ListTile(
        leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: widget.color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Icon(widget.icon, color: widget.color, size: 20)),
        title: Text(widget.label,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, color: widget.color)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
        onTap: () {
          HapticFeedback.selectionClick();
          _ctrl.forward().then((_) => _ctrl.reverse());
          widget.onTap();
        },
      ),
    );
  }
}

class _SheetActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SheetActionButton({required this.label, required this.onTap});
  @override State<_SheetActionButton> createState() => _SheetActionButtonState();
}
class _SheetActionButtonState extends State<_SheetActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.mediumImpact(); _ctrl.forward(); },
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity, height: 50,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient(),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(widget.label,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                    fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _DarkModeToggleTile extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggle;
  const _DarkModeToggleTile({required this.isDark, required this.onToggle});
  @override State<_DarkModeToggleTile> createState() => _DarkModeToggleTileState();
}
class _DarkModeToggleTileState extends State<_DarkModeToggleTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Color?> _bgColor;
  @override void initState() {
    super.initState();
    final color = AppTheme.primary;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100),
        reverseDuration: const Duration(milliseconds: 200));
    _bgColor = ColorTween(begin: Colors.transparent, end: color.withOpacity(0.06))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final iconColor = AppTheme.primary;
    final txtColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary;
    return AnimatedBuilder(
      animation: _bgColor,
      builder: (_, child) => Container(color: _bgColor.value, child: child),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween<double>(begin: 0.75, end: 1.0).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              widget.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              key: ValueKey(widget.isDark),
              color: iconColor, size: 20,
            ),
          ),
        ),
        title: Text(widget.isDark ? 'Dark mode' : 'Light mode',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                fontWeight: FontWeight.w700, color: txtColor)),
        subtitle: Text(widget.isDark ? 'Tap to switch to light' : 'Tap to switch to dark',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary)),
        trailing: Switch.adaptive(
          value: widget.isDark,
          onChanged: (_) => widget.onToggle(),
          activeColor: AppTheme.primary,
          activeTrackColor: AppTheme.primary.withOpacity(0.3),
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey.withOpacity(0.2),
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          _ctrl.forward().then((_) => _ctrl.reverse());
          widget.onToggle();
        },
      ),
    );
  }
}

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _StickyTabBar(this.tabBar);
  @override Widget build(context, __, ___) => Container(color: AppTheme.tabBar(context), child: tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override bool shouldRebuild(covariant _StickyTabBar oldDelegate) => true;
}
