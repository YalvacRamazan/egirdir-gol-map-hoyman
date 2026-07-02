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
