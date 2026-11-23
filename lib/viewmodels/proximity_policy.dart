import 'package:latlong2/latlong.dart';

import 'package:map/models/basket_model.dart';

/// Uzaklık çizgisi ve yakınlık uyarısı için ortak hedef nokta.
/// Aktif kayıtta A noktası; tamamlanmış sepette mesafe olarak en yakın uç.
({double lat, double lon, bool isStart})? targetPointForBasket(
  BasketModel? basket,
  double? lat,
  double? lon,
) {
  if (basket == null || lat == null || lon == null) return null;
  if (!basket.isCompleted || basket.endLatitude == null) {
    return (
      lat: basket.startLatitude,
      lon: basket.startLongitude,
      isStart: true,
    );
  }
  final dA = basket.distanceToStart(lat, lon);
  final dB = basket.distanceToEnd(lat, lon)!;
  return dB < dA
      ? (
          lat: basket.endLatitude!,
          lon: basket.endLongitude!,
          isStart: false,
        )
      : (
          lat: basket.startLatitude,
          lon: basket.startLongitude,
          isStart: true,
        );
}

/// Yakınlık uyarısının saf durum makinesi: eşik tetikleme, %20 hysteresis
/// ile yeniden silahlanma ve 2 saniyelik tekrar kısıtı. Saat dışarıdan
/// verilir; birim testte deterministik çalışır.
class ProximityPolicy {
  ProximityPolicy({required double initialThreshold})
      : _threshold = initialThreshold;

  double _threshold;

  bool _armed = true;

  DateTime? _lastCheck;

  double get threshold => _threshold;

  bool get isArmed => _armed;

  /// Eşiği günceller ve yeniden silahlanır.
  void configure({required double threshold}) {
    _threshold = threshold;
    _armed = true;
  }

  /// Konumu değerlendirir; uyarı üretilirse mesajı, aksi halde null döner.
  String? evaluate({
    required bool enabled,
    required BasketModel? basket,
    required double lat,
    required double lon,
    required DateTime now,
  }) {
    if (!enabled) return null;
    if (_lastCheck != null &&
        now.difference(_lastCheck!) < const Duration(seconds: 2)) {
      return null;
    }
    _lastCheck = now;

    final target = targetPointForBasket(basket, lat, lon);
    if (target == null) return null;
    const calc = Distance();
    final dist = calc.distance(
      LatLng(lat, lon),
      LatLng(target.lat, target.lon),
    );

    if (_armed && dist <= _threshold) {
      _armed = false;
      return 'Hedefe ulaştınız: ${dist.round()} m';
    }
    if (!_armed && dist > _threshold * 1.2) {
      _armed = true;
    }
    return null;
  }
}
