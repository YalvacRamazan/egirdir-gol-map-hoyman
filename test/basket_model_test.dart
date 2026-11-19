import 'package:flutter_test/flutter_test.dart';
import 'package:map/models/basket_model.dart';

void main() {
  group('BasketModel Testleri', () {
    test('toMap ve fromMap dönüşümleri doğru çalışmalıdır', () {
      final now = DateTime.now();
      final basket = BasketModel(
        id: 1,
        name: 'Test Sepeti 1',
        startLatitude: 38.2500,
        startLongitude: 30.9000,
        endLatitude: 38.2550,
        endLongitude: 30.9050,
        startTimestamp: now,
        endTimestamp: now.add(const Duration(minutes: 15)),
        isCompleted: true,
      );

      final map = basket.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Test Sepeti 1');
      expect(map['start_latitude'], 38.2500);
      expect(map['start_longitude'], 30.9000);
      expect(map['end_latitude'], 38.2550);
      expect(map['end_longitude'], 30.9050);
      expect(map['is_completed'], 1);

      final decoded = BasketModel.fromMap(map);
      expect(decoded.id, basket.id);
      expect(decoded.name, basket.name);
      expect(decoded.startLatitude, basket.startLatitude);
      expect(decoded.startLongitude, basket.startLongitude);
      expect(decoded.endLatitude, basket.endLatitude);
      expect(decoded.endLongitude, basket.endLongitude);
      expect(decoded.startTimestamp.toIso8601String(), basket.startTimestamp.toIso8601String());
      expect(decoded.endTimestamp?.toIso8601String(), basket.endTimestamp?.toIso8601String());
      expect(decoded.isCompleted, basket.isCompleted);
    });

    test('startName ve endName toMap/fromMap round-trip doğru çalışmalıdır', () {
      final now = DateTime.now();
      final basket = BasketModel(
        id: 2,
        name: 'Sepet #2',
        startName: 'Kamp Girişi',
        endName: 'Kamp Çıkışı',
        startLatitude: 38.1000,
        startLongitude: 30.9800,
        endLatitude: 38.1100,
        endLongitude: 30.9900,
        startTimestamp: now,
        endTimestamp: now.add(const Duration(minutes: 20)),
        isCompleted: true,
      );

      final map = basket.toMap();
      expect(map['start_name'], 'Kamp Girişi');
      expect(map['end_name'], 'Kamp Çıkışı');

      final decoded = BasketModel.fromMap(map);
      expect(decoded.startName, 'Kamp Girişi');
      expect(decoded.endName, 'Kamp Çıkışı');
      expect(decoded.startDisplayName, 'Kamp Girişi');
      expect(decoded.endDisplayName, 'Kamp Çıkışı');
    });

    test('Eski kayıtlarda start_name/end_name yoksa null okunmalıdır (fallback)', () {
      // v1 şemasından gelen kayıt: yeni kolonlar map içinde yok
      final legacyMap = {
        'id': 3,
        'name': 'Eski Sepet',
        'start_latitude': 38.1000,
        'start_longitude': 30.9800,
        'end_latitude': 38.1100,
        'end_longitude': 30.9900,
        'start_timestamp': '2026-01-01T10:00:00.000',
        'end_timestamp': '2026-01-01T10:15:00.000',
        'is_completed': 1,
      };

      final decoded = BasketModel.fromMap(legacyMap);
      expect(decoded.startName, isNull);
      expect(decoded.endName, isNull);
      // Atanmamış isimler varsayılan etiketle gösterilir
      expect(decoded.startDisplayName, 'A Noktası');
      expect(decoded.endDisplayName, 'B Noktası');
    });

    test('copyWith startName/endName alanlarını güncellemelidir', () {
      final basket = BasketModel(
        name: 'Sepet #4',
        startLatitude: 38.1000,
        startLongitude: 30.9800,
        startTimestamp: DateTime.now(),
      );

      final updated = basket.copyWith(startName: 'Yeni A', endName: 'Yeni B');
      expect(updated.startName, 'Yeni A');
      expect(updated.endName, 'Yeni B');
      // Diğer alanlar korunmalıdır
      expect(updated.name, 'Sepet #4');
      expect(updated.startLatitude, basket.startLatitude);
    });

    test('Mesafe hesaplama (Haversine) doğru sonuç vermelidir', () {
      // Eğirdir Gölü civarında yaklaşık 500 metrelik iki nokta
      final basket = BasketModel(
        name: 'Eğirdir Sepeti',
        startLatitude: 38.2500,
        startLongitude: 30.9000,
        endLatitude: 38.2500,
        endLongitude: 30.90572, // Boylam farkı ~500m
        startTimestamp: DateTime.now(),
      );

      // Yaklaşık 500 metre civarında olmalı (küçük bir hata payı ile)
      expect(basket.distanceInMeters, closeTo(500.0, 5.0));
    });

    test('Bitiş noktası yoksa distanceInMeters 0 dönmelidir', () {
      final basket = BasketModel(
        name: 'Yarım Sepet',
        startLatitude: 38.2500,
        startLongitude: 30.9000,
        startTimestamp: DateTime.now(),
      );

      expect(basket.distanceInMeters, 0.0);
      expect(basket.distanceToEnd(38.2500, 30.9000), isNull);
    });
  });
}
