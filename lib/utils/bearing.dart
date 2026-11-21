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
