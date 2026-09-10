import 'package:flutter/material.dart';
import 'theme.dart';
import 'package:geolocator/geolocator.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showSnack(String message, {bool isError = false}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? AppColors.red : AppColors.brass, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.text, fontSize: 13))),
        ],
      ),
      backgroundColor: AppColors.surface2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isError ? AppColors.red.withOpacity(0.4) : AppColors.line),
      ),
      duration: Duration(seconds: isError ? 4 : 2),
    ),
  );
}

// Requests location permission if needed and returns the device's current
// position, or null (with a snackbar explaining why) if it's unavailable.
Future<Position?> getCurrentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    showSnack('Turn on location services to use this.', isError: true);
    return null;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    showSnack('Location permission was denied.', isError: true);
    return null;
  }
  if (permission == LocationPermission.deniedForever) {
    showSnack('Location permission is blocked. Enable it in your device settings.', isError: true);
    return null;
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  } catch (e) {
    showSnack('Could not get your location.', isError: true);
    return null;
  }
}
extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}