import 'package:flutter_test/flutter_test.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/services/share_service.dart';

void main() {
  group('ShareService.formatBasketMessage', () {
    test('tamamlanmış sepet: A/B isimleri, koordinatlar, bearing ve rotasyon', () {
      final basket = BasketModel(
        name: 'Koy 1',
        startName: 'Fener',
        endName: 'Kayalık',
        startLatitude: 0.0,
        startLongitude: 0.0,
        endLatitude: 0.0,
        endLongitude: 1.0,
        startTimestamp: DateTime(2026, 1, 1, 10, 0),
        endTimestamp: DateTime(2026, 1, 1, 11, 30),
        isCompleted: true,
      );

      final message = ShareService().formatBasketMessage(
        basket,
        currentHeading: 0.0,
      );

      // Başlık ve sepet adı
      expect(message, contains('[GÖL SEPET BİLGİSİ]'));
      expect(message, contains('Koy 1'));

      // A/B isimleri
      expect(message, contains('Fener'));
      expect(message, contains('Kayalık'));

      // A/B koordinatları (mevcut 6 basamak format)
      expect(message, contains('0.000000, 0.000000'));
      expect(message, contains('0.000000, 1.000000'));

      // A→B hedef yönü: doğuya doğru → 90°
      expect(message, contains('Hedef Yön (A→B)'));
      expect(message, contains('90°'));

      // Rotasyon: heading 0 → +90 sağa
      expect(message, contains('Rotasyon'));
      expect(message, contains('90° sağa'));

      // Mesafe ve süre korunur
      expect(message, contains('Sepet Uzunluğu'));
      expect(message, contains('Serim Süresi'));
    });

    test('heading yoksa rotasyon satırı "yön verisi yok" olur', () {
      final basket = BasketModel(
        name: 'Koy 2',
        startLatitude: 0.0,
        startLongitude: 0.0,
        endLatitude: 0.0,
        endLongitude: 1.0,
        startTimestamp: DateTime(2026, 1, 1, 10, 0),
        endTimestamp: DateTime(2026, 1, 1, 11, 0),
        isCompleted: true,
      );

      final message = ShareService().formatBasketMessage(basket);

      expect(message, contains('Hedef Yön (A→B)'));
      expect(message, contains('90°'));
      expect(message, contains('yön verisi yok'));
      expect(message, isNot(contains('sağa')));
      expect(message, isNot(contains('sola')));
    });

    test('negatif rotasyon sola olarak yazılır', () {
      final basket = BasketModel(
        name: 'Koy 3',
        startLatitude: 0.0,
        startLongitude: 0.0,
        endLatitude: 0.0,
        endLongitude: 1.0,
        startTimestamp: DateTime(2026, 1, 1, 10, 0),
        endTimestamp: DateTime(2026, 1, 1, 11, 0),
        isCompleted: true,
      );

      // heading 180 → hedef 90 → en kısa fark -90 (sola)
      final message = ShareService().formatBasketMessage(
        basket,
        currentHeading: 180.0,
      );

      expect(message, contains('Rotasyon'));
      expect(message, contains('90° sola'));
    });

    test('heading hedefe dönükse rotasyon 0° (hedefe dönük) olur', () {
      final basket = BasketModel(
        name: 'Koy 4',
        startLatitude: 0.0,
        startLongitude: 0.0,
        endLatitude: 0.0,
        endLongitude: 1.0,
        startTimestamp: DateTime(2026, 1, 1, 10, 0),
        endTimestamp: DateTime(2026, 1, 1, 11, 0),
        isCompleted: true,
      );

      final message = ShareService().formatBasketMessage(
        basket,
        currentHeading: 90.0,
      );

      expect(message, contains('Rotasyon'));
      expect(message, contains('0° (hedefe dönük)'));
    });

    test('isim alanları boşsa A Noktası / B Noktası fallback kullanılır', () {
      final basket = BasketModel(
        name: 'Koy 5',
        startName: '   ',
        endName: null,
        startLatitude: 0.0,
        startLongitude: 0.0,
        endLatitude: 0.0,
        endLongitude: 1.0,
        startTimestamp: DateTime(2026, 1, 1, 10, 0),
        endTimestamp: DateTime(2026, 1, 1, 11, 0),
        isCompleted: true,
      );

      final message = ShareService().formatBasketMessage(
        basket,
        currentHeading: 0.0,
      );

      expect(message, contains('A Noktası'));
      expect(message, contains('B Noktası'));
      expect(message, isNot(contains('Fener')));
    });

    test('tamamlanmamış sepet: B henüz yerleştirilmedi, bearing/rotasyon yok', () {
      final basket = BasketModel(
        name: 'Koy 6',
        startLatitude: 0.0,
        startLongitude: 0.0,
        startTimestamp: DateTime(2026, 1, 1, 10, 0),
        isCompleted: false,
      );

      final message = ShareService().formatBasketMessage(
        basket,
        currentHeading: 0.0,
      );

      expect(message, contains('Henüz yerleştirilmedi'));
      expect(message, isNot(contains('Hedef Yön')));
      expect(message, isNot(contains('Rotasyon')));
      expect(message, isNot(contains('Sepet Uzunluğu')));
    });
  });
}
