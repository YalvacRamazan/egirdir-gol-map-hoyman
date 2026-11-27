import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/utils/bearing.dart';

void main() {
  group('initialBearing', () {
    test('Ekvator üzerinde batıdan doğuya bearing ≈ 90 olmalı', () {
      final result = initialBearing(const LatLng(0, -1), const LatLng(0, 1));
      expect(result, closeTo(90, 0.001));
    });

    test('Kuzeye doğru bearing ≈ 0 olmalı', () {
      final result = initialBearing(const LatLng(0, 30), const LatLng(10, 30));
      expect(result, closeTo(0, 0.001));
    });

    test('Güneye doğru bearing ≈ 180 olmalı', () {
      final result = initialBearing(const LatLng(10, 30), const LatLng(0, 30));
      expect(result, closeTo(180, 0.001));
    });

    test('Batıya doğru bearing ≈ 270 olmalı', () {
      final result = initialBearing(const LatLng(0, 1), const LatLng(0, -1));
      expect(result, closeTo(270, 0.001));
    });

    test('Aynı noktalar için 0 dönmeli', () {
      final result =
          initialBearing(const LatLng(38.25, 30.9), const LatLng(38.25, 30.9));
      expect(result, 0.0);
    });

    test('Sonlu olmayan koordinatlar NaN dönmeli', () {
      final result = initialBearing(const LatLng(0, 0), LatLng(double.nan, 1));
      expect(result.isNaN, isTrue);
    });
  });

  group('normalizeAngle', () {
    test('370 → 10 olmalı', () {
      expect(normalizeAngle(370), closeTo(10, 1e-9));
    });

    test('-10 → -10 olmalı', () {
      expect(normalizeAngle(-10), closeTo(-10, 1e-9));
    });

    test('180 → -180 olmalı ([-180, 180) aralığı tercih edildi)', () {
      expect(normalizeAngle(180), closeTo(-180, 1e-9));
    });

    test('-180 → -180 olmalı', () {
      expect(normalizeAngle(-180), closeTo(-180, 1e-9));
    });

    test('540 → -180 olmalı', () {
      expect(normalizeAngle(540), closeTo(-180, 1e-9));
    });

    test('NaN girdi NaN dönmeli', () {
      expect(normalizeAngle(double.nan).isNaN, isTrue);
    });

    test('Infinity girdi NaN dönmeli', () {
      expect(normalizeAngle(double.infinity).isNaN, isTrue);
    });
  });

  group('shortestAngleDifference', () {
    test('target 350, heading 10 → -20 (saat yönünün tersine 20°)', () {
      expect(shortestAngleDifference(350, 10), closeTo(-20, 1e-9));
    });

    test('target 10, heading 350 → +20 (saat yönünde 20°)', () {
      expect(shortestAngleDifference(10, 350), closeTo(20, 1e-9));
    });

    test('target 90, heading 270 → -180 (tam ters yön; [-180, 180) aralığı)', () {
      expect(shortestAngleDifference(90, 270), closeTo(-180, 1e-9));
    });

    test('target 0, heading 359 → +1', () {
      expect(shortestAngleDifference(0, 359), closeTo(1, 1e-9));
    });

    test('Sonlu olmayan girdi NaN dönmeli', () {
      expect(shortestAngleDifference(double.nan, 0).isNaN, isTrue);
    });
  });

  group('cardinalLabel', () {
    test('0 → K', () => expect(cardinalLabel(0), 'K'));
    test('90 → D', () => expect(cardinalLabel(90), 'D'));
    test('180 → G', () => expect(cardinalLabel(180), 'G'));
    test('270 → B', () => expect(cardinalLabel(270), 'B'));
    test('360 → K', () => expect(cardinalLabel(360), 'K'));
    test('-90 → B', () => expect(cardinalLabel(-90), 'B'));
    test('45 → D (sektör sınırı)', () => expect(cardinalLabel(45), 'D'));
    test('315 → K (sektör sınırı)', () => expect(cardinalLabel(315), 'K'));
    test('NaN → null', () => expect(cardinalLabel(double.nan), isNull));
    test('Infinity → null', () => expect(cardinalLabel(double.infinity), isNull));
  });

  group('smoothHeadingCircular (pusula yumuşatma)', () {
    test('previous null iken current aynen döner', () {
      expect(smoothHeadingCircular(null, 90), 90);
    });

    test('previous sonlu değilse current aynen döner', () {
      expect(smoothHeadingCircular(double.nan, 90), 90);
    });

    test('current sonlu değilse previous korunur', () {
      expect(smoothHeadingCircular(90, double.nan), 90);
      expect(smoothHeadingCircular(90, double.infinity), 90);
    });

    test('aynı açı aynı açıyı döner', () {
      expect(smoothHeadingCircular(45, 45), closeTo(45, 1e-9));
    });

    test('sonuç previous ile current arasında kalır (kısa yoldan)', () {
      // 350 → 10: kısa yol 350 → 360/0 → 10 yönündedir.
      final smoothed = smoothHeadingCircular(350, 10);
      // Dairesel ortalama 350'nin saat yönünde ilerlemiş hali olmalı.
      final delta = shortestAngleDifference(smoothed, 350);
      expect(delta, greaterThan(0));
      expect(delta, lessThan(10));
    });

    test('0/360 sarımında sıçramaz', () {
      final smoothed = smoothHeadingCircular(359, 1);
      // 359 ile 1 arasındaki dairesel orta ~0 civarında olmalı.
      final delta = headingDeltaForTest(smoothed, 0);
      expect(delta, lessThan(2));
    });

    test('alpha=1 tamamen current değerine geçer', () {
      expect(smoothHeadingCircular(350, 10, alpha: 1), closeTo(10, 1e-9));
    });

    test('sonuç her zaman [0, 360) aralığında', () {
      for (double prev = 0; prev < 360; prev += 30) {
        for (double cur = 0; cur < 360; cur += 30) {
          final smoothed = smoothHeadingCircular(prev, cur);
          expect(smoothed >= 0 && smoothed < 360, isTrue,
              reason: 'prev=$prev cur=$cur smoothed=$smoothed');
        }
      }
    });
  });

  group('BasketModel bearing getter', () {
    test('initialBearing A→B bearing üretmeli', () {
      final basket = BasketModel(
        name: 'Bearing Sepeti',
        startLatitude: 0,
        startLongitude: -1,
        endLatitude: 0,
        endLongitude: 1,
        startTimestamp: DateTime.now(),
      );

      expect(basket.initialBearing, closeTo(90, 0.001));
    });

    test('Bitiş noktası yoksa initialBearing null dönmeli', () {
      final basket = BasketModel(
        name: 'Yarım Sepet',
        startLatitude: 38.25,
        startLongitude: 30.9,
        startTimestamp: DateTime.now(),
      );

      expect(basket.initialBearing, isNull);
    });

    test('initialBearingFrom hedef bearing ile heading arasındaki rotasyonu dönmeli', () {
      final basket = BasketModel(
        name: 'Rotasyon Sepeti',
        startLatitude: 0,
        startLongitude: -1,
        endLatitude: 0,
        endLongitude: 1, // bearing ≈ 90 (doğu)
        startTimestamp: DateTime.now(),
      );

      // Kuzeye (0°) bakan kullanıcı saat yönünde 90° dönmeli.
      expect(basket.initialBearingFrom(0), closeTo(90, 0.001));
      // Batıya (270°) bakan kullanıcı saat yönünün tersine 180° dönmeli.
      expect(basket.initialBearingFrom(270), closeTo(-180, 1e-9));
    });

    test('initialBearingFrom heading null ise null dönmeli', () {
      final basket = BasketModel(
        name: 'Rotasyon Sepeti',
        startLatitude: 0,
        startLongitude: -1,
        endLatitude: 0,
        endLongitude: 1,
        startTimestamp: DateTime.now(),
      );

      expect(basket.initialBearingFrom(null), isNull);
    });

    test('Bitiş noktası yoksa initialBearingFrom null dönmeli', () {
      final basket = BasketModel(
        name: 'Yarım Sepet',
        startLatitude: 38.25,
        startLongitude: 30.9,
        startTimestamp: DateTime.now(),
      );

      expect(basket.initialBearingFrom(45), isNull);
    });
  });
}

double headingDeltaForTest(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}
