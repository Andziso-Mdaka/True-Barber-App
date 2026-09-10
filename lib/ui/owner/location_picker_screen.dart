import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../widgets/primary_button.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? picked;
  bool locating = false;
  final mapController = MapController();

  static const _fallback = LatLng(-26.2041, 28.0473); // Johannesburg

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      picked = widget.initial;
    } else {
      _useCurrentLocation(silent: true);
    }
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    setState(() => locating = true);
    final pos = await getCurrentPosition();
    if (pos != null) {
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => picked = point);
      mapController.move(point, 15);
    } else if (!silent) {
      // getCurrentPosition already showed a snackbar explaining why.
    }
    if (mounted) setState(() => locating = false);
  }

  @override
  Widget build(BuildContext context) {
    final center = picked ?? _fallback;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Set shop location', style: TextStyle(color: AppColors.text, fontSize: 16)),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              "Tap anywhere on the map to place the pin, or drag the map under it. Doesn't need to be exact.",
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: picked != null ? 15 : 11,
                    onTap: (tapPosition, point) => setState(() => picked = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.theregular.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (picked != null)
                          Marker(
                            point: picked!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: AppColors.red, size: 40),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'locate',
                    backgroundColor: AppColors.surface2,
                    onPressed: locating ? null : _useCurrentLocation,
                    child: locating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brass),
                          )
                        : const Icon(Icons.my_location, color: AppColors.brass, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton(
              label: picked == null ? 'Tap the map to place a pin' : 'Confirm this location',
              onTap: picked == null ? () {} : () => Navigator.of(context).pop(picked),
            ),
          ),
        ],
      ),
    );
  }
}
