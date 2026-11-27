import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

double _toRadians(double degrees) => degrees * math.pi / 180.0;

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

double normalizeAngle(double degrees) {
  if (!degrees.isFinite) return double.nan;
  return ((degrees + 180.0) % 360.0) - 180.0;
}

double shortestAngleDifference(double targetBearing, double currentHeading) {
  return normalizeAngle(targetBearing - currentHeading);
}

String? cardinalLabel(double heading) {
  if (!heading.isFinite) return null;
  final normalized = heading % 360.0;
  const labels = ['K', 'D', 'G', 'B'];
  return labels[((normalized + 45.0) / 90.0).floor() % 4];
}

/// Dairesel üstel yumuşatma (0/360 sarımına dayanıklı EMA): pusula iğnesinin
/// sensör gürültüsünde sık atlamasını önler. Önceki ve anlık açı birim
/// vektörlere çevrilip ağırlıklı ortalanır; [alpha] anlık değerin payıdır.
/// [previous] null ya da sonlu değilse [current] aynen döner; [current]
/// sonlu değilse [previous] korunur. Tam zıt açılarda sıfır vektör
/// riskine karşı önceki değer döner.
double smoothHeadingCircular(
  double? previous,
  double current, {
  double alpha = 0.12,
}) {
  if (previous == null || !previous.isFinite) return current;
  if (!current.isFinite) return previous;

  final prevRad = previous * math.pi / 180.0;
  final curRad = current * math.pi / 180.0;
  final sin = (1 - alpha) * math.sin(prevRad) + alpha * math.sin(curRad);
  final cos = (1 - alpha) * math.cos(prevRad) + alpha * math.cos(curRad);

  final magnitude = math.sqrt(sin * sin + cos * cos);
  if (magnitude < 1e-6) return previous;

  final degrees = math.atan2(sin, cos) * 180.0 / math.pi;
  return (degrees + 360.0) % 360.0;
}
