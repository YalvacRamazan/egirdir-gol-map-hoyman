import 'package:flutter_test/flutter_test.dart';
import 'package:map/services/sqlite_tile_cache_service.dart';

void main() {
  group('selectTileIdsToEvict', () {
    final now = DateTime(2026, 1, 1, 12, 0);
    const maxAge = Duration(days: 30);
    const maxBytes = 1000;
    const dayMs = 86400000;

    TileMeta tile(int id, {required int ageDays, required int size}) =>
        TileMeta(
          id: id,
          timestamp: now.millisecondsSinceEpoch - ageDays * dayMs,
          size: size,
        );

    test('Sınır altındaysa boş liste döner', () {
      final tiles = [
        tile(1, ageDays: 1, size: 100),
        tile(2, ageDays: 2, size: 100),
        tile(3, ageDays: 3, size: 100),
      ];

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, isEmpty);
    });

    test('Toplam boyut sınıra tam eşitse silme yapılmaz', () {
      final tiles = [
        tile(1, ageDays: 1, size: 500),
        tile(2, ageDays: 2, size: 500),
      ];

      final result = selectTileIdsToEvict(tiles, 1000, now, maxAge);

      expect(result, isEmpty);
    });

    test('Yaş aşımı: maxAge\'ten eski tile silinir, yeniler kalır', () {
      final tiles = [
        tile(1, ageDays: 31, size: 100), // eski
        tile(2, ageDays: 29, size: 100), // taze
        tile(3, ageDays: 1, size: 100),
      ];

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [1]);
    });

    test('Migration satırları (timestamp=0) yaş aşımına takılır', () {
      final tiles = [
        const TileMeta(id: 1, timestamp: 0, size: 100),
        tile(2, ageDays: 1, size: 100),
      ];

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [1]);
    });

    test('Birden fazla eski tile en eskiden yeniye sıralı döner', () {
      final tiles = [
        tile(3, ageDays: 40, size: 100),
        tile(1, ageDays: 60, size: 100),
        tile(2, ageDays: 50, size: 100),
        tile(4, ageDays: 5, size: 100),
      ];

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [1, 2, 3]);
    });

    test('Boyut aşımı: en eski yazılandan başlayarak siler', () {
      final tiles = [
        tile(1, ageDays: 20, size: 600), // en eski
        tile(2, ageDays: 10, size: 600),
        tile(3, ageDays: 1, size: 600), // en yeni
      ];
      // Toplam 1800 > 1000: id 1 silinir (1200), hâlâ aşım var:
      // id 2 silinir (600 ≤ 1000) → dur.

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [1, 2]);
    });

    test('Boyut aşımı sınırın altına inince durur', () {
      final tiles = [
        tile(1, ageDays: 20, size: 600),
        tile(2, ageDays: 10, size: 300),
        tile(3, ageDays: 1, size: 300),
      ];
      // Toplam 1200 > 1000: id 1 silinir → 600 ≤ 1000 → dur.

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [1]);
    });

    test('Yaş aşımı ve boyut aşımı birlikte uygulanır', () {
      final tiles = [
        tile(1, ageDays: 40, size: 100), // yaş aşımı
        tile(2, ageDays: 10, size: 700), // boyut aşımı (en eski survivor)
        tile(3, ageDays: 5, size: 700),
      ];
      // Survivor toplamı 1400 > 1000 → id 2 silinir → 700 ≤ 1000.

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [1, 2]);
    });

    test('Tek tile bile sınırı aşıyorsa silinir', () {
      final tiles = [tile(1, ageDays: 1, size: 2000)];

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [1]);
    });

    test('Boş liste güvenli şekilde boş döner', () {
      final result = selectTileIdsToEvict([], maxBytes, now, maxAge);

      expect(result, isEmpty);
    });
  });
}
