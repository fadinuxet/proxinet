import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class ProxinetPresenceService {
  Future<Position?> getCityLevelPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          return null;
        }
      }
      
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
        return pos;
      } catch (e) {
        print('Error getting position: $e');
        return null;
      }
    } catch (e) {
      print('Permission error: $e');
      return null;
    }
  }

  Future<String?> getCurrentCityName() async {
    try {
      final pos = await getCityLevelPosition();
      if (pos == null) return null;
      
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isEmpty) return null;
        final p = placemarks.first;
        return p.locality?.isNotEmpty == true
            ? p.locality
            : p.administrativeArea ?? p.country;
      } catch (e) {
        print('Geocoding error: $e');
        return null;
      }
    } catch (e) {
      print('Error getting city name: $e');
      return null;
    }
  }
}
