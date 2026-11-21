import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:map/utils/bearing.dart' as bearing;

class BasketModel {
  final int? id;
  final String name;
  final String? startName;
  final String? endName;
  final double startLatitude;
  final double startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final DateTime startTimestamp;
  final DateTime? endTimestamp;
  final bool isCompleted;

  BasketModel({
    this.id,
    required this.name,
    this.startName,
    this.endName,
    required this.startLatitude,
    required this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    required this.startTimestamp,
    this.endTimestamp,
    this.isCompleted = false,
  });

  String get startDisplayName => (startName == null || startName!.trim().isEmpty)
      ? 'A Noktası'
      : startName!;

  String get endDisplayName => (endName == null || endName!.trim().isEmpty)
      ? 'B Noktası'
      : endName!;

  double get distanceInMeters {
    if (endLatitude == null || endLongitude == null) return 0.0;
    return _calculateDistance(
      startLatitude,
      startLongitude,
      endLatitude!,
      endLongitude!,
    );
  }

  double? get initialBearing {
    if (endLatitude == null || endLongitude == null) return null;
    return bearing.initialBearing(
      LatLng(startLatitude, startLongitude),
      LatLng(endLatitude!, endLongitude!),
    );
  }

  double? initialBearingFrom(double? currentHeading) {
    if (currentHeading == null) return null;
    final target = initialBearing;
    if (target == null) return null;
    return bearing.shortestAngleDifference(target, currentHeading);
  }

  double distanceToStart(double lat, double lon) {
    return _calculateDistance(lat, lon, startLatitude, startLongitude);
  }

  double? distanceToEnd(double lat, double lon) {
    if (endLatitude == null || endLongitude == null) return null;
    return _calculateDistance(lat, lon, endLatitude!, endLongitude!);
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180.0;

  double? distanceToLine(double cLat, double cLon) {
    if (endLatitude == null || endLongitude == null) return null;

    final projection = projectionPoint(cLat, cLon);
    if (projection == null) return null;

    return _calculateDistance(cLat, cLon, projection.$1, projection.$2);
  }

  (double lat, double lon)? projectionPoint(double cLat, double cLon) {
    if (endLatitude == null || endLongitude == null) return null;

    final double xA = startLongitude, yA = startLatitude;
    final double xB = endLongitude!, yB = endLatitude!;
    final double xC = cLon, yC = cLat;

    final double abX = xB - xA;
    final double abY = yB - yA;
    final double acX = xC - xA;
    final double acY = yC - yA;

    final double dotProduct = acX * abX + acY * abY;
    final double abLenSq = abX * abX + abY * abY;

    double t = (abLenSq != 0.0) ? dotProduct / abLenSq : 0.0;
    if (t < 0.0) t = 0.0;
    if (t > 1.0) t = 1.0;

    final double pLat = yA + t * abY;
    final double pLon = xA + t * abX;

    return (pLat, pLon);
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'start_name': startName,
      'end_name': endName,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'start_timestamp': startTimestamp.toIso8601String(),
      'end_timestamp': endTimestamp?.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory BasketModel.fromMap(Map<String, dynamic> map) {
    return BasketModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      startName: map['start_name'] as String?,
      endName: map['end_name'] as String?,
      startLatitude: (map['start_latitude'] as num).toDouble(),
      startLongitude: (map['start_longitude'] as num).toDouble(),
      endLatitude: (map['end_latitude'] as num?)?.toDouble(),
      endLongitude: (map['end_longitude'] as num?)?.toDouble(),
      startTimestamp: DateTime.parse(map['start_timestamp'] as String),
      endTimestamp: map['end_timestamp'] != null 
          ? DateTime.parse(map['end_timestamp'] as String) 
          : null,
      isCompleted: (map['is_completed'] as int) == 1,
    );
  }

  BasketModel copyWith({
    int? id,
    String? name,
    String? startName,
    String? endName,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    DateTime? startTimestamp,
    DateTime? endTimestamp,
    bool? isCompleted,
  }) {
    return BasketModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startName: startName ?? this.startName,
      endName: endName ?? this.endName,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      startTimestamp: startTimestamp ?? this.startTimestamp,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
