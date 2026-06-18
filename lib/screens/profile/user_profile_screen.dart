import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/listing_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_card.dart';
import '../listing/listing_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String fallbackName;
  final String? fallbackAvatar;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.fallbackName,
    this.fallbackAvatar,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserModel? _user;
  List<ListingModel> _listings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final userRes = await ApiService.getUser(widget.userId);
      final listingRes = await ApiService.getUserListings(widget.userId);
      if (!mounted) return;
      setState(() {
        if (userRes['success'] == true) {
          _user = UserModel.fromJson(userRes['data']['user']);
        }
        if (listingRes['success'] == true) {
          final data = listingRes['data']['listings'] as List;
          _listings = data.map((e) => ListingModel.fromJson(e)).toList();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _user = UserModel.fromJson({
          '_id': widget.userId,
          'name': widget.fallbackName,
          'avatar': widget.fallbackAvatar,
          'stats': {},
          'badges': [],
        });
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _resolveAvatar(String avatar) {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http') || avatar.startsWith('file://')) return avatar;
    if (avatar.startsWith('/uploads')) return 'https://foodwasteapp-production-6eaa.up.railway.app$avatar';
    if (avatar.startsWith('/')) return 'file://$avatar';
    return avatar;
  }

  ImageProvider? _avatarProvider(String avatarUrl) {
    final resolved = _resolveAvatar(avatarUrl);
    if (resolved.isEmpty) return null;
    if (resolved.startsWith('file://')) {
      return FileImage(File(Uri.parse(resolved).toFilePath(windows: Platform.isWindows)));
    }
    return CachedNetworkImageProvider(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(user?.name ?? widget.fallbackName),
        backgroundColor: AppTheme.surface(context),
        foregroundColor: AppTheme.txtPrimary(context),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.divider),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _fetchProfile,
              color: AppTheme.primary,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(user)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                      child: Row(children: [
                        Expanded(child: Text('Active listings', style: TextStyle(
                          fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800,
                          color: AppTheme.txtPrimary(context),
                        ))),
                        Text('${_listings.length} items', style: TextStyle(
                          fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        )),
                      ]),
                    ),
                  ),
                  if (_listings.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No active listings yet', style: TextStyle(
                        fontFamily: 'Nunito', color: AppTheme.txtSecondary(context), fontSize: 14,
                      ))),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => ListingCard(
                            listing: _listings[i],
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ListingDetailScreen(listingId: _listings[i].id),
                            )),
                          ),
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
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(UserModel? user) {
    final name = user?.name.isNotEmpty == true ? user!.name : widget.fallbackName;
    final avatar = user?.avatarUrl ?? widget.fallbackAvatar ?? '';
    return Container(
      width: double.infinity,
      color: AppTheme.surface(context),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: AppTheme.primary.withOpacity(0.12),
          backgroundImage: _avatarProvider(avatar),
          child: avatar.isEmpty
              ? Text(name.substring(0, 1).toUpperCase(), style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 30, fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ))
              : null,
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text(name, style: TextStyle(
            fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800,
            color: AppTheme.txtPrimary(context),
          ), overflow: TextOverflow.ellipsis)),
          if (user?.isVerified == true) ...[
            const SizedBox(width: 6),
            Icon(Icons.verified_rounded, color: AppTheme.primary, size: 19),
          ],
        ]),
        if (user?.bio.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(user!.bio, textAlign: TextAlign.center, style: TextStyle(
            fontFamily: 'Nunito', fontSize: 13, height: 1.5, color: AppTheme.txtSecondary(context),
          )),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            _stat('${user?.stats.totalShared ?? _listings.length}', 'Shared'),
            Container(width: 1, height: 34, color: AppTheme.divider),
            _stat('${user?.stats.totalReceived ?? 0}', 'Received'),
            Container(width: 1, height: 34, color: AppTheme.divider),
            _stat('${user?.stats.mealsaved ?? 0}', 'Meals saved'),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String value, String label) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(
      fontFamily: 'Nunito', fontSize: 19, fontWeight: FontWeight.w800,
      color: AppTheme.primary,
    )),
    const SizedBox(height: 2),
    Text(label, textAlign: TextAlign.center, style: TextStyle(
      fontFamily: 'Nunito', fontSize: 11, color: AppTheme.txtSecondary(context),
    )),
  ]));
}
