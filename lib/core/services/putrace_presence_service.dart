import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class PutracePresenceService {
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
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium, // Standardized for optimal battery/accuracy balance
            timeLimit: Duration(seconds: 10),
          ),
        );
        return pos;
      } catch (e) {
        
        return null;
      }
    } catch (e) {
      
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
        
        return null;
      }
    } catch (e) {
      
      return null;
    }
  }
}
