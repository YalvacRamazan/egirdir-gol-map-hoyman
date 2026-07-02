import 'dart:math';

class BasketModel {
  final int? id;
  final String name;
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
    required this.startLatitude,
    required this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    required this.startTimestamp,
    this.endTimestamp,
    this.isCompleted = false,
  });

  /// Sepetin başlangıç ve bitiş noktası arasındaki mesafeyi metre cinsinden döner.
  double get distanceInMeters {
    if (endLatitude == null || endLongitude == null) return 0.0;
    return _calculateDistance(
      startLatitude,
      startLongitude,
      endLatitude!,
      endLongitude!,
    );
  }

  /// Belirli bir koordinatın başlangıç noktasına olan uzaklığını metre cinsinden döner.
  double distanceToStart(double lat, double lon) {
    return _calculateDistance(lat, lon, startLatitude, startLongitude);
  }

  /// Belirli bir koordinatın bitiş noktasına olan uzaklığını metre cinsinden döner.
  double? distanceToEnd(double lat, double lon) {
    if (endLatitude == null || endLongitude == null) return null;
    return _calculateDistance(lat, lon, endLatitude!, endLongitude!);
  }

  /// Haversine formülü ile iki nokta arasındaki mesafeyi (metre) hesaplar.
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // PI / 180
    final c = cos;
    final a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p))/2;
    return 12742000 * asin(sqrt(a)); // 2 * R * 1000 (R = 6371 km)
  }

  /// Veritabanına kaydetmek için Map nesnesine dönüştürür.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'start_timestamp': startTimestamp.toIso8601String(),
      'end_timestamp': endTimestamp?.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  /// Veritabanından gelen Map nesnesinden BasketModel üretir.
  factory BasketModel.fromMap(Map<String, dynamic> map) {
    return BasketModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      startLatitude: map['start_latitude'] as double,
      startLongitude: map['start_longitude'] as double,
      endLatitude: map['end_latitude'] as double?,
      endLongitude: map['end_longitude'] as double?,
      startTimestamp: DateTime.parse(map['start_timestamp'] as String),
      endTimestamp: map['end_timestamp'] != null 
          ? DateTime.parse(map['end_timestamp'] as String) 
          : null,
      isCompleted: (map['is_completed'] as int) == 1,
    );
  }

  /// Yeni değerlerle kopyasını oluşturur.
  BasketModel copyWith({
    int? id,
    String? name,
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
