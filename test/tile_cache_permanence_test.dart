import 'package:flutter_test/flutter_test.dart';
import 'package:map/services/sqlite_tile_cache_service.dart';

void main() {
  group('selectTileIdsToEvict kalıcılık (isPermanent)', () {
    final now = DateTime(2026, 1, 1, 12, 0);
    const maxAge = Duration(days: 30);
    const maxBytes = 1000;
    const dayMs = 86400000;

    TileMeta tile(
      int id, {
      required int ageDays,
      required int size,
      bool isPermanent = false,
    }) =>
        TileMeta(
          id: id,
          timestamp: now.millisecondsSinceEpoch - ageDays * dayMs,
          size: size,
          isPermanent: isPermanent,
        );

    test('Geçici tile yaş ve boyut limitinde normal şekilde seçilir', () {
      final tiles = [
        tile(1, ageDays: 31, size: 100), // yaş aşımı
        tile(2, ageDays: 10, size: 700),
        tile(3, ageDays: 5, size: 700),
      ];
      // Survivor toplamı 1400 > 1000: id 2 de seçilir → 700 ≤ 1000.

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [1, 2]);
    });

    test('Kalıcı tile yaş aşımında bile seçilmez', () {
      final tiles = [
        tile(1, ageDays: 365, size: 100, isPermanent: true),
        tile(2, ageDays: 31, size: 100),
      ];

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [2]);
    });

    test('Kalıcı tile boyut sınırı aşımında bile seçilmez', () {
      final tiles = [
        tile(1, ageDays: 1, size: 5000, isPermanent: true),
        tile(2, ageDays: 10, size: 700),
        tile(3, ageDays: 5, size: 700),
      ];
      // Geçici survivor toplamı 1400 > 1000: id 2 seçilir → 700 ≤ 1000 → dur.
      // Boyutu büyük kalıcı tile dokunulmadan kalır.

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [2]);
    });

    test('Tüm tile kalıcıysa boş liste döner', () {
      final tiles = [
        tile(1, ageDays: 100, size: 900, isPermanent: true),
        tile(2, ageDays: 1, size: 900, isPermanent: true),
      ];

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, isEmpty);
    });

    test('Karışık listede yalnızca uygun geçici tile seçilir', () {
      final tiles = [
        tile(1, ageDays: 60, size: 400, isPermanent: true), // eski kalıcı
        tile(2, ageDays: 1, size: 400), // yeni geçici
        tile(3, ageDays: 40, size: 400), // eski geçici (yaş aşımı)
        tile(4, ageDays: 2, size: 400, isPermanent: true), // taze kalıcı
      ];

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [3]);
    });

    test('Kalıcı tile sınırları zorlarken geçiciler yine ölçüle göre silinir',
        () {
      final tiles = [
        tile(1, ageDays: 100, size: 900, isPermanent: true),
        tile(2, ageDays: 20, size: 600),
        tile(3, ageDays: 10, size: 600),
        tile(4, ageDays: 1, size: 600),
      ];
      // Geçici survivor toplamı 1800 > 1000: id 2 (600), id 3 (600) silinir.

      final result = selectTileIdsToEvict(tiles, maxBytes, now, maxAge);

      expect(result, [2, 3]);
    });

    test('TileMeta varsayılan isPermanent false olur', () {
      const meta = TileMeta(id: 1, timestamp: 0, size: 100);

      expect(meta.isPermanent, isFalse);
    });

    test('fromRow is_permanent=1 satırını kalıcı okur', () {
      final permanent = TileMeta.fromRow(
        {'id': 7, 'timestamp': 123, 'size': 456, 'is_permanent': 1},
      );
      final temporary = TileMeta.fromRow(
        {'id': 8, 'timestamp': 124, 'size': 456, 'is_permanent': 0},
      );

      expect(permanent.isPermanent, isTrue);
      expect(temporary.isPermanent, isFalse);
    });
  });
}
