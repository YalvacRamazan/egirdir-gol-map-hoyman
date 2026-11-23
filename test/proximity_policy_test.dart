import 'package:flutter_test/flutter_test.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/viewmodels/proximity_policy.dart';

void main() {
  final baseTime = DateTime(2026, 1, 1, 10, 0, 0);

  // A=(38.1000, 30.9800), B=(38.1100, 30.9900). 0.0001 derece
  // yaklaşık 11 m (enlem) ve 8.7 m (boylam) eder.
  BasketModel completedBasket() => BasketModel(
        name: 'Tamamlanan Sepet',
        startLatitude: 38.1000,
        startLongitude: 30.9800,
        endLatitude: 38.1100,
        endLongitude: 30.9900,
        startTimestamp: DateTime(2026, 1, 1, 8, 0),
        endTimestamp: DateTime(2026, 1, 1, 8, 30),
        isCompleted: true,
      );

  BasketModel activeBasket() => BasketModel(
        name: 'Aktif Sepet',
        startLatitude: 38.1000,
        startLongitude: 30.9800,
        startTimestamp: DateTime(2026, 1, 1, 8, 0),
      );

  group('targetPointForBasket', () {
    test('Aktif sepet için hedef her zaman A noktasıdır', () {
      final target = targetPointForBasket(activeBasket(), 38.1100, 30.9900);

      expect(target, isNotNull);
      expect(target!.isStart, isTrue);
      expect(target.lat, 38.1000);
      expect(target.lon, 30.9800);
    });

    test('Tamamlanmış sepette B daha yakınsa hedef B olur', () {
      final target = targetPointForBasket(completedBasket(), 38.1099, 30.9899);

      expect(target, isNotNull);
      expect(target!.isStart, isFalse);
      expect(target.lat, 38.1100);
      expect(target.lon, 30.9900);
    });

    test('Tamamlanmış sepette A daha yakınsa hedef A olur', () {
      final target = targetPointForBasket(completedBasket(), 38.1001, 30.9801);

      expect(target, isNotNull);
      expect(target!.isStart, isTrue);
      expect(target.lat, 38.1000);
      expect(target.lon, 30.9800);
    });

    test('isCompleted false olsa da B koordinatı varsa hedef A kalır', () {
      final basket = completedBasket().copyWith(isCompleted: false);
      final target = targetPointForBasket(basket, 38.1099, 30.9899);

      expect(target, isNotNull);
      expect(target!.isStart, isTrue);
    });

    test('Sepet veya konum yoksa null döner', () {
      expect(targetPointForBasket(null, 38.1, 30.98), isNull);
      expect(targetPointForBasket(completedBasket(), null, null), isNull);
    });
  });

  group('ProximityPolicy', () {
    late ProximityPolicy policy;

    setUp(() {
      policy = ProximityPolicy(initialThreshold: 25.0);
    });

    test('Mesafe eşiğin altındayken uyarı üretir ve silahsızlanır', () {
      final alert = policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.1099,
        lon: 30.9899,
        now: baseTime,
      );

      expect(alert, isNotNull);
      expect(alert, contains('Hedefe ulaştınız'));
      expect(policy.isArmed, isFalse);
    });

    test('Silahsızken eşik ile eşik*1.2 arasında yeniden silahlanmaz', () {
      policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.1099,
        lon: 30.9899,
        now: baseTime,
      );

      // Mesafe ~26 m: eşiğin üstünde ama 30 m hysteresis bandının altında.
      final alert = policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.11022,
        lon: 30.9899,
        now: baseTime.add(const Duration(seconds: 2)),
      );

      expect(alert, isNull);
      expect(policy.isArmed, isFalse);
    });

    test('Silahsızken eşik*1.2 üzerine çıkınca yeniden silahlanır', () {
      policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.1099,
        lon: 30.9899,
        now: baseTime,
      );

      policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.11022,
        lon: 30.9899,
        now: baseTime.add(const Duration(seconds: 2)),
      );

      // Mesafe ~45 m: hysteresis bandının üstünde.
      final alert = policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.11040,
        lon: 30.9899,
        now: baseTime.add(const Duration(seconds: 4)),
      );

      expect(alert, isNull);
      expect(policy.isArmed, isTrue);
    });

    test('Yeniden silahlandıktan sonra yakınlık yeniden uyarı üretir', () {
      policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.1099,
        lon: 30.9899,
        now: baseTime,
      );

      policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.11022,
        lon: 30.9899,
        now: baseTime.add(const Duration(seconds: 2)),
      );

      policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.11040,
        lon: 30.9899,
        now: baseTime.add(const Duration(seconds: 4)),
      );

      final alert = policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.1099,
        lon: 30.9899,
        now: baseTime.add(const Duration(seconds: 6)),
      );

      expect(alert, isNotNull);
      expect(policy.isArmed, isFalse);
    });

    test('Aynı 2 saniye içinde ikinci tetikleme yapılmaz', () {
      // Uzaktan geçiş sayacı tazeler, uyarı üretmez.
      policy.evaluate(
        enabled: true,
        basket: activeBasket(),
        lat: 38.1050,
        lon: 30.9850,
        now: baseTime,
      );

      // 1 sn sonra hedefin dibinde: kısıt nedeniyle tetikleme atlanır.
      final second = policy.evaluate(
        enabled: true,
        basket: activeBasket(),
        lat: 38.10005,
        lon: 30.9800,
        now: baseTime.add(const Duration(seconds: 1)),
      );
      expect(second, isNull);
      expect(policy.isArmed, isTrue);

      // 2 sn dolduktan sonraki ilk kontrol uyarı üretir.
      final third = policy.evaluate(
        enabled: true,
        basket: activeBasket(),
        lat: 38.10005,
        lon: 30.9800,
        now: baseTime.add(const Duration(seconds: 2)),
      );
      expect(third, isNotNull);
    });

    test('Kapalıyken uyarı üretilmez ve 2 sn sayacı ilerlemez', () {
      final disabled = policy.evaluate(
        enabled: false,
        basket: activeBasket(),
        lat: 38.10005,
        lon: 30.9800,
        now: baseTime,
      );
      expect(disabled, isNull);

      // Kapalıyken sayaç güncellenmediği için açılış anında tetiklenebilir.
      final enabled = policy.evaluate(
        enabled: true,
        basket: activeBasket(),
        lat: 38.10005,
        lon: 30.9800,
        now: baseTime,
      );
      expect(enabled, isNotNull);
    });

    test('configure yeni eşiğe geçer ve yeniden silahlanır', () {
      policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.1099,
        lon: 30.9899,
        now: baseTime,
      );
      expect(policy.isArmed, isFalse);

      policy.configure(threshold: 50.0);
      expect(policy.threshold, 50.0);
      expect(policy.isArmed, isTrue);

      // Mesafe ~24 m: eski 25 m eşiğiyle sınırda, 50 m eşiğinde tetikler.
      final alert = policy.evaluate(
        enabled: true,
        basket: completedBasket(),
        lat: 38.1102,
        lon: 30.9899,
        now: baseTime.add(const Duration(seconds: 2)),
      );
      expect(alert, isNotNull);
    });
  });
}
