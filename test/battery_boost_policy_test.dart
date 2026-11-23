import 'package:flutter_test/flutter_test.dart';
import 'package:map/services/battery_service.dart';

void main() {
  group('BatteryService.shouldUseBoostFromLevel', () {
    test('Yüksek seviyede boost seçilir', () {
      expect(BatteryService.shouldUseBoostFromLevel(100), isTrue);
      expect(BatteryService.shouldUseBoostFromLevel(51), isTrue);
    });

    test('%50 ve altında tasarruf seçilir', () {
      expect(BatteryService.shouldUseBoostFromLevel(50), isFalse);
      expect(BatteryService.shouldUseBoostFromLevel(49), isFalse);
      expect(BatteryService.shouldUseBoostFromLevel(0), isFalse);
    });

    test('Seviye okunamadığında doğruluk lehine boost seçilir', () {
      expect(BatteryService.shouldUseBoostFromLevel(null), isTrue);
    });
  });
}
