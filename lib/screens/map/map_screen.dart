import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../models/listing_model.dart';
import '../../theme/app_theme.dart';
import '../listing/listing_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  Position? _position;
  List<ListingModel> _listings = [];
  ListingModel? _selected;
  bool _loading = true;

  // Default: Jakarta
  static const _default = LatLng(-6.2088, 106.8456);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.deniedForever) {
        _position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }
    } catch (_) {}
    await _fetchListings();
    setState(() => _loading = false);
  }

  Future<void> _fetchListings() async {
    try {
      final lat = _position?.latitude ?? _default.latitude;
      final lng = _position?.longitude ?? _default.longitude;
      final res = await ApiService.getNearbyListings(lat, lng, radius: 20000);
      if (res['success'] == true) {
        final data = res['data']['listings'] as List;
        setState(() => _listings = data.map((e) => ListingModel.fromJson(e)).toList());
      }
    } catch (e) {
      debugPrint('Map fetch error: $e');
    }
  }

  LatLng get _center => _position != null
      ? LatLng(_position!.latitude, _position!.longitude)
      : _default;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              onTap: (_, __) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sharebite.app',
              ),
              // User location marker
              if (_position != null)
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(_position!.latitude, _position!.longitude),
                    width: 44, height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 12)],
                      ),
                      child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              // Listing markers
              MarkerLayer(
                markers: _listings.map((l) {
                  final color = AppTheme.categoryColors[l.category] ?? AppTheme.primary;
                  return Marker(
                    point: LatLng(l.location.lat, l.location.lng),
                    width: 40, height: 40,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = l),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _selected?.id == l.id ? color : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 2.5),
                          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: Icon(Icons.restaurant_outlined,
                            color: _selected?.id == l.id ? Colors.white : color, size: 18),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Loading overlay
          if (_loading)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)],
                  ),
                  child: Row(children: [
                    Icon(Icons.location_on_outlined, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _loading ? 'Loading...' : '${_listings.length} listings nearby',
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                            fontWeight: FontWeight.w700, color: AppTheme.txtPrimary(context)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () { setState(() => _loading = true); _fetchListings().then((_) => setState(() => _loading = false)); },
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 18),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          // Locate me button
          Positioned(
            right: 16,
            bottom: _selected != null ? 200 : 24,
            child: Column(children: [
              GestureDetector(
                onTap: () {
                  if (_position != null) {
                    _mapCtrl.move(LatLng(_position!.latitude, _position!.longitude), 15);
                  }
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
                  ),
                  child: Icon(Icons.my_location_rounded, color: AppTheme.primary, size: 22),
                ),
              ),
            ]),
          ),

          // Selected listing card
          if (_selected != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildSelectedCard(_selected!),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedCard(ListingModel l) {
    final catColor = AppTheme.categoryColors[l.category] ?? AppTheme.primary;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30)],
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.restaurant_outlined, color: catColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.title, style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                fontSize: 15, color: AppTheme.txtPrimary(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: catColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(l.isFree ? 'FREE' : 'Rp ${l.price.toStringAsFixed(0)}',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700, color: catColor)),
              ),
              if (l.distanceText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.location_on_outlined, size: 13, color: AppTheme.txtSecondary(context)),
                Text(l.distanceText, style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppTheme.txtSecondary(context))),
              ],
            ]),
          ])),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: l.id))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(12)),
              child: Text('View', style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
