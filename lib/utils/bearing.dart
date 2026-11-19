import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Dereceyi radyana çevirir.
double _toRadians(double degrees) => degrees * math.pi / 180.0;

/// İki coğrafi nokta arasındaki büyük daire (great-circle) başlangıç
/// bearing'ini derece cinsinden döner; sonuç [0, 360) aralığındadır.
///
/// Kuzey 0°, doğu 90°, güney 180°, batı 270°.
/// Aynı noktalar için 0 döner. Koordinatlar sonlu değilse (NaN/Infinity)
/// [double.nan] döner.
double initialBearing(LatLng from, LatLng to) {
  if (!from.latitude.isFinite ||
      !from.longitude.isFinite ||
      !to.latitude.isFinite ||
      !to.longitude.isFinite) {
    return double.nan;
  }

  final phi1 = _toRadians(from.latitude);
  final phi2 = _toRadians(to.latitude);
  final deltaLambda = _toRadians(to.longitude - from.longitude);

  final x = math.sin(deltaLambda) * math.cos(phi2);
  final y = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

  final thetaDegrees = math.atan2(x, y) * 180.0 / math.pi;
  return (thetaDegrees + 360.0) % 360.0;
}

/// Açıyı [-180, 180) aralığına normalize eder.
///
/// Tercih: [-180, 180) aralığı seçilmiştir; böylece tam 180° sınır değeri
/// -180° olarak döner ve [shortestAngleDifference] davranışıyla tutarlı kalır.
/// Sonlu olmayan girdi (NaN/Infinity) [double.nan] döner.
double normalizeAngle(double degrees) {
  if (!degrees.isFinite) return double.nan;
  // Dart'ta % operatörü negatif olmayan sonuç üretir (Euclidean modulo).
  return ((degrees + 180.0) % 360.0) - 180.0;
}

/// Hedef bearing ile mevcut yön (heading) arasındaki en kısa işaretli açı
/// farkını derece cinsinden döner; sonuç [-180, 180) aralığındadır.
///
/// Pozitif değer saat yönünde (clockwise), negatif değer saat yönünün tersine
/// (counter-clockwise) dönüşü gösterir. Tam 180° fark durumu -180 döner
/// ([normalizeAngle] ile aynı aralık tercihi).
/// Sonlu olmayan girdi (NaN/Infinity) [double.nan] döner.
double shortestAngleDifference(double targetBearing, double currentHeading) {
  return normalizeAngle(targetBearing - currentHeading);
}

/// Verilen yön açısına (heading) karşılık gelen Türkçe ana yön etiketini döner.
///
/// 4 yönlüdür: K (kuzey), D (doğu), G (güney), B (batı) — DESIGN.md'deki
/// "kuzey, güney, doğu ve batı" etiketleriyle uyumlu.
/// Sektör sınırları 45°'dir: [315, 45) → K, [45, 135) → D, [135, 225) → G,
/// [225, 315) → B.
/// Sonlu olmayan girdi (NaN/Infinity) null döner.
String? cardinalLabel(double heading) {
  if (!heading.isFinite) return null;
  final normalized = heading % 360.0;
  const labels = ['K', 'D', 'G', 'B'];
  return labels[((normalized + 45.0) / 90.0).floor() % 4];
}
