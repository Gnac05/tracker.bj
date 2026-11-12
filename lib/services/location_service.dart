import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationState { loading, ready, denied, serviceOff }

/// Position de l'utilisateur. À défaut, on se replie sur le centre de
/// Cotonou pour que les listes restent utilisables.
class LocationService extends ChangeNotifier {
  static const fallbackLat = 6.3654;
  static const fallbackLng = 2.4183;

  LocationState state = LocationState.loading;
  double lat = fallbackLat;
  double lng = fallbackLng;

  bool get hasFix => state == LocationState.ready;

  Future<void> refresh() async {
    state = LocationState.loading;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = LocationState.serviceOff;
        notifyListeners();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = LocationState.denied;
        notifyListeners();
        return;
      }
      final last = await _lastKnown();
      if (last != null) _set(last);
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      _set(pos);
    } catch (_) {
      if (state != LocationState.ready) {
        state = LocationState.denied;
        notifyListeners();
      }
    }
  }

  Future<Position?> _lastKnown() async {
    if (kIsWeb) return null;
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  void _set(Position p) {
    lat = p.latitude;
    lng = p.longitude;
    state = LocationState.ready;
    notifyListeners();
  }

  /// Distance en mètres entre l'utilisateur et un point.
  double distanceTo(double toLat, double toLng) =>
      Geolocator.distanceBetween(lat, lng, toLat, toLng);

  Future<void> openSettings() async {
    // Dans un navigateur, l'autorisation se règle dans la barre d'adresse.
    if (kIsWeb) return;
    if (state == LocationState.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
