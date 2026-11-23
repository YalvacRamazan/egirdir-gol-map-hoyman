import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:map/services/hoyman_tile_region.dart';

// Referans dönüşümler: OSM wiki'deki standart Web Mercator formülleri.
int lonToTileX(double lon, int zoom) =>
    ((lon + 180.0) / 360.0 * math.pow(2, zoom)).floor();

int latToTileY(double lat, int zoom) =>
    ((1.0 -
            math.log(math.tan(lat * math.pi / 180) +
                    1 / math.cos(lat * math.pi / 180)) /
                math.pi) /
        2 *
        math.pow(2, zoom))
        .floor();

void main() {
  group('HoymanTileRegion.containsLatLng', () {
    test('Bbox sınır değerleri dahil sayılır', () {
      expect(
        HoymanTileRegion.containsLatLng(
          HoymanTileRegion.south,
          HoymanTileRegion.west,
        ),
        isTrue,
      );
      expect(
        HoymanTileRegion.containsLatLng(
          HoymanTileRegion.north,
          HoymanTileRegion.east,
        ),
        isTrue,
      );
      expect(
        HoymanTileRegion.containsLatLng(
          HoymanTileRegion.south,
          HoymanTileRegion.east,
        ),
        isTrue,
      );
      expect(
        HoymanTileRegion.containsLatLng(
          HoymanTileRegion.north,
          HoymanTileRegion.west,
        ),
        isTrue,
      );
    });

    test('Bbox dışındaki noktalar reddedilir', () {
      expect(
        HoymanTileRegion.containsLatLng(
          HoymanTileRegion.south - 0.001,
          31.0,
        ),
        isFalse,
      );
      expect(
        HoymanTileRegion.containsLatLng(
          HoymanTileRegion.north + 0.001,
          31.0,
        ),
        isFalse,
      );
      expect(
        HoymanTileRegion.containsLatLng(38.125, HoymanTileRegion.west - 0.001),
        isFalse,
      );
      expect(
        HoymanTileRegion.containsLatLng(38.125, HoymanTileRegion.east + 0.001),
        isFalse,
      );
    });
  });

  group('HoymanTileRegion.containsTile', () {
    test('Bbox köşelerini içeren tile bölgede sayılır', () {
      for (final z in [
        HoymanTileRegion.minZoom,
        12,
        HoymanTileRegion.maxZoom,
      ]) {
        final xWest = lonToTileX(HoymanTileRegion.west, z);
        final xEast = lonToTileX(HoymanTileRegion.east, z);
        final yNorth = latToTileY(HoymanTileRegion.north, z);
        final ySouth = latToTileY(HoymanTileRegion.south, z);
        expect(
          HoymanTileRegion.containsTile(z, xWest, yNorth),
          isTrue,
          reason: 'NW kesişim bekleniyor (z=$z)',
        );
        expect(
          HoymanTileRegion.containsTile(z, xEast, yNorth),
          isTrue,
          reason: 'NE kesişim bekleniyor (z=$z)',
        );
        expect(
          HoymanTileRegion.containsTile(z, xWest, ySouth),
          isTrue,
          reason: 'SW kesişim bekleniyor (z=$z)',
        );
        expect(
          HoymanTileRegion.containsTile(z, xEast, ySouth),
          isTrue,
          reason: 'SE kesişim bekleniyor (z=$z)',
        );
      }
    });

    test('Bbox dışı tile reddedilir', () {
      const z = 10;
      final xWest = lonToTileX(HoymanTileRegion.west, z);
      final xEast = lonToTileX(HoymanTileRegion.east, z);
      final yNorth = latToTileY(HoymanTileRegion.north, z);
      final ySouth = latToTileY(HoymanTileRegion.south, z);
      final yMid = (yNorth + ySouth) ~/ 2;

      expect(
        HoymanTileRegion.containsTile(z, xWest - 1, yMid),
        isFalse,
        reason: 'Batı komşusu tile bölgenin batısında kalır',
      );
      expect(
        HoymanTileRegion.containsTile(z, xEast + 1, yMid),
        isFalse,
        reason: 'Doğu komşusu tile bölgenin doğusunda kalır',
      );
      expect(
        HoymanTileRegion.containsTile(z, xWest, yNorth - 1),
        isFalse,
        reason: 'Kuzey komşusu tile bölgenin kuzeyinde kalır',
      );
      expect(
        HoymanTileRegion.containsTile(z, xWest, ySouth + 1),
        isFalse,
        reason: 'Güney komşusu tile bölgenin güneyinde kalır',
      );
    });

    test('minZoom-1 ve maxZoom+1 zoomlar reddedilir', () {
      final zLow = HoymanTileRegion.minZoom - 1;
      final xLow = lonToTileX(31.0, zLow);
      final yLow = latToTileY(38.125, zLow);
      expect(HoymanTileRegion.containsTile(zLow, xLow, yLow), isFalse);

      final zHigh = HoymanTileRegion.maxZoom + 1;
      final xHigh = lonToTileX(31.0, zHigh);
      final yHigh = latToTileY(38.125, zHigh);
      expect(HoymanTileRegion.containsTile(zHigh, xHigh, yHigh), isFalse);
    });

    test('z=0 tile lat aralığı Web Mercator sabitine uyar', () {
      // (0,0) tile'inin kuzey ve güney kenarları ±85.0511 derecedir.
      expect(HoymanTileRegion.tile2lat(0, 0), closeTo(85.0511, 0.0001));
      expect(HoymanTileRegion.tile2lat(1, 0), closeTo(-85.0511, 0.0001));
    });
  });

  group('HoymanTileRegion tile sayımı', () {
    test('tileCount pozitiftir', () {
      expect(HoymanTileRegion.tileCount(), greaterThan(0));
    });

    test('allTiles uzunluğu tileCount ile eşittir', () {
      expect(HoymanTileRegion.allTiles().length, HoymanTileRegion.tileCount());
    });

    test('allTiles içindeki her tile containsTile ile doğrulanır', () {
      for (final (z, x, y) in HoymanTileRegion.allTiles()) {
        expect(
          HoymanTileRegion.containsTile(z, x, y),
          isTrue,
          reason: 'z=$z x=$x y=$y tile beklenmedik şekilde bölge dışı',
        );
      }
    });

    test('Her zoom seviyesi tile üretir', () {
      final zooms = HoymanTileRegion.allTiles().map((t) => t.$1).toSet();
      for (var z = HoymanTileRegion.minZoom;
          z <= HoymanTileRegion.maxZoom;
          z++) {
        expect(zooms, contains(z), reason: 'z=$z için tile üretilmedi');
      }
    });

    test('z=10 için bilinen tile sayısı 6dır (2 sütun x 3 satır)', () {
      final z10 = HoymanTileRegion.allTiles().where((t) => t.$1 == 10);
      expect(z10.length, 6);
    });
  });
}
