import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../storage/local_storage.dart';

enum LocationPermissionState { granted, denied, permanentlyDenied, serviceDisabled }

class LocationResult {
  final double? lat;
  final double? lng;
  final LocationPermissionState state;
  final String? error;
  final bool isManual;
  const LocationResult({this.lat, this.lng, required this.state, this.error, this.isManual = false});
  bool get hasLocation => lat != null && lng != null;
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // Erode district fallback (centre of district) when GPS unavailable
  static const double fallbackLat = 11.3410;
  static const double fallbackLng = 77.7172;

  Future<LocationPermissionState> checkPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionState.serviceDisabled;
    final status = await Permission.location.status;
    if (status.isGranted) return LocationPermissionState.granted;
    if (status.isPermanentlyDenied) return LocationPermissionState.permanentlyDenied;
    return LocationPermissionState.denied;
  }

  Future<LocationResult> requestAndGetLocation() async {
    // Check service
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult(state: LocationPermissionState.serviceDisabled, error: 'Location services disabled. Enable GPS or enter location manually.', isManual: false);
    }
    // Request permission
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }
    if (status.isPermanentlyDenied) {
      return LocationResult(state: LocationPermissionState.permanentlyDenied, error: 'Location permission permanently denied. Enable from settings or enter manually.');
    }
    if (!status.isGranted) {
      return LocationResult(state: LocationPermissionState.denied, error: 'Location permission denied.');
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      // cache
      await LocalStorage.instance.setString('last_lat', pos.latitude.toString());
      await LocalStorage.instance.setString('last_lng', pos.longitude.toString());
      return LocationResult(lat: pos.latitude, lng: pos.longitude, state: LocationPermissionState.granted);
    } catch (e) {
      // fallback to last known
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return LocationResult(lat: last.latitude, lng: last.longitude, state: LocationPermissionState.granted);
        }
      } catch (_) {}
      return LocationResult(state: LocationPermissionState.granted, error: 'Could not get GPS fix: $e');
    }
  }

  // Manual fallback: allow user to enter lat/lng or select district
  Future<LocationResult> manualLocation({required double lat, required double lng}) async {
    await LocalStorage.instance.setString('last_lat', lat.toString());
    await LocalStorage.instance.setString('last_lng', lng.toString());
    await LocalStorage.instance.setString('manual_lat', lat.toString());
    await LocalStorage.instance.setString('manual_lng', lng.toString());
    return LocationResult(lat: lat, lng: lng, state: LocationPermissionState.granted, isManual: true);
  }

  LocationResult? getCachedLocation() {
    final latStr = LocalStorage.instance.getString('last_lat');
    final lngStr = LocalStorage.instance.getString('last_lng');
    if (latStr != null && lngStr != null) {
      final lat = double.tryParse(latStr);
      final lng = double.tryParse(lngStr);
      if (lat != null && lng != null) return LocationResult(lat: lat, lng: lng, state: LocationPermissionState.granted, isManual: LocalStorage.instance.getString('manual_lat') != null);
    }
    return null;
  }

  Future<bool> openSettings() => openAppSettings();
}
