import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/utils/bearing.dart';

/// Pusula/rotasyon saf mantık testleri:
/// - heading → ok açısı dönüşümü (derece → radyan, Transform.rotate girdisi)
/// - heading yokken rotasyon null
/// - bearing'e göre rotasyon işareti (pozitif saat yönü / negatif ters)
void main() {
  group('heading → ok açısı dönüşümü', () {
    // Harita oku: Transform.rotate(angle: heading * pi / 180).
    // 0° kuzey (ok yukarı), 90° doğu (ok sağa), saat yönü pozitif.
    double headingToRotationRadians(double heading) => heading * 3.141592653589793 / 180.0;

    test('0° kuzey → 0 radyan (ok yukarı)', () {
      expect(headingToRotationRadians(0), closeTo(0, 1e-9));
    });

    test('90° doğu → yarım pi radyan (ok sağa)', () {
      expect(headingToRotationRadians(90), closeTo(1.5707963267948966, 1e-9));
    });

    test('180° güney → pi radyan (ok aşağı)', () {
      expect(headingToRotationRadians(180), closeTo(3.141592653589793, 1e-9));
    });

    test('270° batı → 3/2 pi radyan (ok sola)', () {
      expect(headingToRotationRadians(270), closeTo(4.71238898038469, 1e-9));
    });

    test('360°+ değerler mod 2π sonrası aynı görsel açıyı verir', () {
      // Transform.rotate açıyı mod 2π yorumlar; 450° ≡ 90° (mod 360°).
      const twoPi = 6.283185307179586;
      final diff = (headingToRotationRadians(450) - headingToRotationRadians(90)) % twoPi;
      expect(diff, closeTo(0, 1e-9));
    });
  });

  group('rotasyon işareti (shortestAngleDifference)', () {
    test('hedef doğu (90°), cihaz kuzeye bakıyor (0°) → +90° sağa', () {
      expect(shortestAngleDifference(90, 0), closeTo(90, 1e-9));
    });

    test('hedef batı (270°), cihaz kuzeye bakıyor (0°) → -90° sola', () {
      expect(shortestAngleDifference(270, 0), closeTo(-90, 1e-9));
    });

    test('hedef güney (180°), cihaz kuzeye bakıyor (0°) → -180° (aralık tercihi)', () {
      expect(shortestAngleDifference(180, 0), closeTo(-180, 1e-9));
    });

    test('hedef kuzey (0°), cihaz güneye bakıyor (180°) → -180°', () {
      expect(shortestAngleDifference(0, 180), closeTo(-180, 1e-9));
    });

    test('hedef ve heading aynı → 0°', () {
      expect(shortestAngleDifference(123, 123), closeTo(0, 1e-9));
    });

    test('hedef 10°, heading 350° → +20° (en kısa yol saat yönü)', () {
      expect(shortestAngleDifference(10, 350), closeTo(20, 1e-9));
    });

    test('hedef 350°, heading 10° → -20° (en kısa yol saat yönünün tersi)', () {
      expect(shortestAngleDifference(350, 10), closeTo(-20, 1e-9));
    });

    test('sonuç her zaman [-180, 180) aralığında', () {
      for (double target = 0; target < 360; target += 15) {
        for (double heading = 0; heading < 360; heading += 15) {
          final diff = shortestAngleDifference(target, heading);
          expect(diff >= -180 && diff < 180, isTrue,
              reason: 'target=$target heading=$heading diff=$diff');
        }
      }
    });
  });

  group('cardinalLabel (pusula etiketleri)', () {
    test('0° → K', () => expect(cardinalLabel(0), 'K'));
    test('45° sınırı → D', () => expect(cardinalLabel(45), 'D'));
    test('90° → D', () => expect(cardinalLabel(90), 'D'));
    test('135° → G', () => expect(cardinalLabel(135), 'G'));
    test('180° → G', () => expect(cardinalLabel(180), 'G'));
    test('225° → B', () => expect(cardinalLabel(225), 'B'));
    test('270° → B', () => expect(cardinalLabel(270), 'B'));
    test('315° → K', () => expect(cardinalLabel(315), 'K'));
    test('359° → K', () => expect(cardinalLabel(359), 'K'));
    test('NaN → null', () => expect(cardinalLabel(double.nan), isNull));
  });

  group('heading yokken rotasyon null (BasketModel.initialBearingFrom)', () {
    // BasketModel.initialBearingFrom(currentHeading) contract'ı:
    // heading null → null; B noktası yok → null.
    // Burada aynı sözleşmeyi bearing util üzerinden saf olarak test ederiz.
    double? rotationFrom(double? heading, double? targetBearing) {
      if (heading == null) return null;
      if (targetBearing == null) return null;
      return shortestAngleDifference(targetBearing, heading);
    }

    test('heading null → rotasyon null', () {
      expect(rotationFrom(null, 90), isNull);
    });

    test('hedef bearing null → rotasyon null', () {
      expect(rotationFrom(45, null), isNull);
    });

    test('ikisi de varsa işaretli en kısa açı döner', () {
      expect(rotationFrom(0, 90), closeTo(90, 1e-9));
      expect(rotationFrom(0, 270), closeTo(-90, 1e-9));
    });
  });

  group('initialBearing (A→B hedef yönü)', () {
    test('kuzeye giden hat → 0°', () {
      final bearing = initialBearing(
        const LatLng(38.0, 30.0),
        const LatLng(38.1, 30.0),
      );
      expect(bearing, closeTo(0, 0.1));
    });

    test('doğuya giden hat → 90°', () {
      final bearing = initialBearing(
        const LatLng(38.0, 30.0),
        const LatLng(38.0, 30.1),
      );
      expect(bearing, closeTo(90, 0.1));
    });

    test('güneye giden hat → 180°', () {
      final bearing = initialBearing(
        const LatLng(38.1, 30.0),
        const LatLng(38.0, 30.0),
      );
      expect(bearing, closeTo(180, 0.1));
    });

    test('batıya giden hat → 270°', () {
      final bearing = initialBearing(
        const LatLng(38.0, 30.1),
        const LatLng(38.0, 30.0),
      );
      expect(bearing, closeTo(270, 0.1));
    });
  });
}
