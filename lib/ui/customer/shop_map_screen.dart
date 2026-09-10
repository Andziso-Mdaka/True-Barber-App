import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../core/utils.dart'; // For getCurrentPosition()
import '../../models/shop.dart';

class ShopMapScreen extends StatefulWidget {
  final List<Shop> shops;
  final void Function(Shop) onOpen;
  final bool refreshingShops;
  final Future<void> Function() onRefreshShops;
  const ShopMapScreen({
    super.key,
    required this.shops,
    required this.onOpen,
    required this.refreshingShops,
    required this.onRefreshShops,
  });

  @override
  State<ShopMapScreen> createState() => _ShopMapScreenState();
}

class _ShopMapScreenState extends State<ShopMapScreen> {
  Position? myPosition;
  bool loading = true;
  String? error;
  final mapController = MapController();

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      loading = true;
      error = null;
    });
    final pos = await getCurrentPosition();
    setState(() {
      myPosition = pos;
      loading = false;
      if (pos == null) error = "Couldn't get your location. Showing shops without centering the map.";
    });
  }

  double? _distanceKm(Shop shop) {
    if (myPosition == null || shop.latitude == null || shop.longitude == null) return null;
    final meters = Geolocator.distanceBetween(
      myPosition!.latitude,
      myPosition!.longitude,
      shop.latitude!,
      shop.longitude!,
    );
    return meters / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final located = widget.shops.where((s) => s.latitude != null && s.longitude != null).toList();
    final center = myPosition != null
        ? LatLng(myPosition!.latitude, myPosition!.longitude)
        : (located.isNotEmpty ? LatLng(located.first.latitude!, located.first.longitude!) : const LatLng(-26.2041, 28.0473)); // Johannesburg fallback

    final sorted = [...located]
      ..sort((a, b) => (_distanceKm(a) ?? 999999).compareTo(_distanceKm(b) ?? 999999));

    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brass));
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(initialCenter: center, initialZoom: 13),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.theregular.app',
                  ),
                  MarkerLayer(
                    markers: [
                      if (myPosition != null)
                        Marker(
                          point: LatLng(myPosition!.latitude, myPosition!.longitude),
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.brass,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.bg, width: 3),
                            ),
                          ),
                        ),
                      for (final shop in located)
                        Marker(
                          point: LatLng(shop.latitude!, shop.longitude!),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => widget.onOpen(shop),
                            child: const Icon(Icons.content_cut, color: AppColors.red, size: 32),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (error != null)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(error!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: _locate,
                          child: const Text('Retry', style: TextStyle(color: AppColors.brass, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton.small(
                  heroTag: 'refresh_shops',
                  backgroundColor: AppColors.surface2,
                  onPressed: widget.refreshingShops ? null : widget.onRefreshShops,
                  child: widget.refreshingShops
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brass),
                        )
                      : const Icon(Icons.refresh, color: AppColors.brass, size: 20),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: RefreshIndicator(
            color: AppColors.brass,
            backgroundColor: AppColors.surface,
            onRefresh: widget.onRefreshShops,
            child: sorted.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(
                          child: Text("No shops have a location set yet.", style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final shop in sorted) _NearbyShopCard(shop: shop, distanceKm: _distanceKm(shop), onTap: () => widget.onOpen(shop)),
                      if (widget.shops.length > located.length)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "${widget.shops.length - located.length} shop(s) haven't set a location yet and aren't shown here.",
                            style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _NearbyShopCard extends StatelessWidget {
  final Shop shop;
  final double? distanceKm;
  final VoidCallback onTap;
  const _NearbyShopCard({required this.shop, required this.distanceKm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${shop.area} · R${shop.price}/mo', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (distanceKm != null)
              Text(
                distanceKm! < 1 ? '${(distanceKm! * 1000).round()} m' : '${distanceKm!.toStringAsFixed(1)} km',
                style: const TextStyle(color: AppColors.brass, fontSize: 13, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
