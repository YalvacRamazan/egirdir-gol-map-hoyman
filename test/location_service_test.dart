import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map/services/location_service.dart';

void main() {
  group('LocationService Doğruluk Filtresi Testleri', () {
    late LocationService locationService;

    setUp(() {
      locationService = LocationService();
      locationService.accuracyThreshold = 15.0; // Eşiği 15 metreye sabitleyelim
    });

    Position createMockPosition(double accuracy) {
      return Position(
        latitude: 38.2500,
        longitude: 30.9000,
        timestamp: DateTime.now(),
        accuracy: accuracy,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    test('Doğruluk eşiğin altındaysa konum kabul edilmelidir', () {
      final position = createMockPosition(10.0); // 10 metre sapma (kabul edilebilir)
      expect(locationService.isAccuracyAcceptable(position), isTrue);
    });

    test('Doğruluk eşiğe tam eşitse konum kabul edilmelidir', () {
      final position = createMockPosition(15.0); // 15 metre sapma
      expect(locationService.isAccuracyAcceptable(position), isTrue);
    });

    test('Doğruluk eşiğin üzerindeyse konum reddedilmelidir', () {
      final position = createMockPosition(25.0); // 25 metre sapma (kabul edilemez)
      expect(locationService.isAccuracyAcceptable(position), isFalse);
    });

    test('Doğruluk eşiği dinamik olarak değiştirilebilmelidir', () {
      locationService.accuracyThreshold = 30.0;
      final position = createMockPosition(25.0);
      expect(locationService.isAccuracyAcceptable(position), isTrue);
    });
  });
}
