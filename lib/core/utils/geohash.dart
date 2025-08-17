class Geohash {
  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String encode(double latitude, double longitude, {int precision = 7}) {
    // precision 7 ~ 153m, 6 ~ 1.2km, 5 ~ 5km approx
    var minLat = -90.0, maxLat = 90.0;
    var minLon = -180.0, maxLon = 180.0;
    final buffer = StringBuffer();
    var isEven = true;
    var bit = 0;
    var ch = 0;

    while (buffer.length < precision) {
      if (isEven) {
        final mid = (minLon + maxLon) / 2;
        if (longitude > mid) {
          ch |= 1 << (4 - bit);
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (latitude > mid) {
          ch |= 1 << (4 - bit);
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }
      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return buffer.toString();
  }

  // pick geohash precision for a given radius in km
  static int precisionForRadiusKm(double radiusKm) {
    if (radiusKm <= 0.25) return 8; // ~19m
    if (radiusKm <= 0.5) return 7; // ~153m
    if (radiusKm <= 1.5) return 6; // ~1.2km
    if (radiusKm <= 5) return 5; // ~5km
    if (radiusKm <= 20) return 4; // ~39km
    return 3; // ~156km
  }

  static String prefixRangeEnd(String prefix) {
    // endAt prefix + '\uf8ff' is common pattern
    return '$prefix\uf8ff';
  }
}
