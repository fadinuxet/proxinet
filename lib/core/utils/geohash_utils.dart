// Simple geohash implementation for Putrace
class GeoHashUtils {
  static const String _base32 = "0123456789bcdefghjkmnpqrstuvwxyz";
  
  static String encode(double latitude, double longitude, {int precision = 7}) {
    double latMin = -90.0;
    double latMax = 90.0;
    double lngMin = -180.0;
    double lngMax = 180.0;
    
    String geohash = "";
    bool isEven = true;
    int bit = 0;
    int ch = 0;
    
    while (geohash.length < precision) {
      if (isEven) {
        double mid = (lngMin + lngMax) / 2;
        if (longitude >= mid) {
          ch |= (1 << (4 - bit));
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        double mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          ch |= (1 << (4 - bit));
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      
      isEven = !isEven;
      
      if (bit < 4) {
        bit++;
      } else {
        geohash += _base32[ch];
        bit = 0;
        ch = 0;
      }
    }
    
    return geohash;
  }
  
  static List<String> neighbors(String geohash) {
    List<String> neighbors = [];
    
    // Get the 8 neighbors around the given geohash
    String north = _adjacent(geohash, 'n');
    String south = _adjacent(geohash, 's');
    String east = _adjacent(geohash, 'e');
    String west = _adjacent(geohash, 'w');
    
    neighbors.addAll([
      north,
      _adjacent(north, 'e'),
      east,
      _adjacent(south, 'e'),
      south,
      _adjacent(south, 'w'),
      west,
      _adjacent(north, 'w'),
    ]);
    
    return neighbors;
  }
  
  static String _adjacent(String geohash, String direction) {
    // Simplified adjacent calculation
    // In a real implementation, this would be more complex
    int lastChar = geohash.length - 1;
    String base = geohash.substring(0, lastChar);
    String last = geohash[lastChar];
    
    int lastIndex = _base32.indexOf(last);
    
    switch (direction) {
      case 'n':
        if (lastIndex < 16) {
          return base + _base32[lastIndex + 16];
        } else {
          return _adjacent(base, 'n') + _base32[lastIndex - 16];
        }
      case 's':
        if (lastIndex >= 16) {
          return base + _base32[lastIndex - 16];
        } else {
          return _adjacent(base, 's') + _base32[lastIndex + 16];
        }
      case 'e':
        if (lastIndex % 2 == 0) {
          return base + _base32[lastIndex + 1];
        } else {
          return _adjacent(base, 'e') + _base32[lastIndex - 1];
        }
      case 'w':
        if (lastIndex % 2 == 1) {
          return base + _base32[lastIndex - 1];
        } else {
          return _adjacent(base, 'w') + _base32[lastIndex + 1];
        }
      default:
        return geohash;
    }
  }
}
