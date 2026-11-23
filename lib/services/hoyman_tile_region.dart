import 'dart:math' as math;

/// Hoyman Gölü kalıcı tile bölgesi (bbox + zoom aralığı).
/// Sabitler tek yerden değiştirilebilir; saha testinde genişletilebilir.
class HoymanTileRegion {
  static const double south = 37.95;
  static const double north = 38.30;
  static const double west = 30.80;
  static const double east = 31.20;
  static const int minZoom = 10;
  static const int maxZoom = 15;

  static bool containsLatLng(double lat, double lon) =>
      lat >= south && lat <= north && lon >= west && lon <= east;

  /// Web Mercator tile bbox'ı bölgeyle kesişiyorsa true döner.
  static bool containsTile(int z, int x, int y) {
    if (z < minZoom || z > maxZoom) return false;
    final n = math.pow(2, z).toDouble();
    final lonW = x / n * 360.0 - 180.0;
    final lonE = (x + 1) / n * 360.0 - 180.0;
    final latN = tile2lat(y, z);
    final latS = tile2lat(y + 1, z);
    return latS < north && latN > south && lonW < east && lonE > west;
  }

  /// Tile satırının kuzey kenarının enlemi (standart Web Mercator dönüşümü).
  static double tile2lat(int y, int z) {
    final n = math.pow(2, z).toDouble();
    // dart:math'te sinh yok; sinh(x) = (e^x - e^-x) / 2.
    final x = math.pi * (1 - 2 * y / n);
    final sinhX = (math.exp(x) - math.exp(-x)) / 2;
    return math.atan(sinhX) * 180 / math.pi;
  }

  /// Bölge içindeki tüm (z, x, y) tile koordinatları.
  static List<(int, int, int)> allTiles() {
    final tiles = <(int, int, int)>[];
    for (var z = minZoom; z <= maxZoom; z++) {
      final xMin = _lon2tileX(west, z), xMax = _lon2tileX(east, z);
      final yMin = _lat2tileY(north, z), yMax = _lat2tileY(south, z);
      for (var x = xMin; x <= xMax; x++) {
        for (var y = yMin; y <= yMax; y++) {
          if (containsTile(z, x, y)) tiles.add((z, x, y));
        }
      }
    }
    return tiles;
  }

  /// Bölge içindeki toplam tile sayısı (indirme öncesi boyut tahmini).
  static int tileCount() {
    var count = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      final xMin = _lon2tileX(west, z), xMax = _lon2tileX(east, z);
      final yMin = _lat2tileY(north, z), yMax = _lat2tileY(south, z);
      count += (xMax - xMin + 1) * (yMax - yMin + 1);
    }
    return count;
  }

  static int _lon2tileX(double lon, int z) =>
      ((lon + 180.0) / 360.0 * math.pow(2, z)).floor();

  static int _lat2tileY(double lat, int z) =>
      ((1.0 - math.log(math.tan(lat * math.pi / 180) +
              1 / math.cos(lat * math.pi / 180)) / math.pi) /
          2 * math.pow(2, z)).floor();
}
