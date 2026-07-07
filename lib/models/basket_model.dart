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
  /// Standart formül — CODES.md ile uyumlu (R = 6371000 m).
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000.0; // Dünya yarıçapı (metre)
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180.0;

  /// Kullanıcının (C) sepet ipi (A→B) üzerindeki en yakın noktaya olan mesafesini
  /// metre cinsinden döner. CODES.md'deki canliMesafeHesapla algoritması.
  ///
  /// Vektör izdüşümü ile A-B doğrusu üzerindeki en yakın P noktasını bulur,
  /// ardından C-P arası Haversine mesafesini hesaplar.
  /// Sepet tamamlanmamışsa null döner.
  double? distanceToLine(double cLat, double cLon) {
    if (endLatitude == null || endLongitude == null) return null;

    final projection = projectionPoint(cLat, cLon);
    if (projection == null) return null;

    return _calculateDistance(cLat, cLon, projection.$1, projection.$2);
  }

  /// Kullanıcının (C) konumunun sepet ipi (A→B) üzerindeki izdüşüm noktasını (P)
  /// döner. Sonuç (lat, lon) tuple'ıdır. Sepet tamamlanmamışsa null döner.
  (double lat, double lon)? projectionPoint(double cLat, double cLon) {
    if (endLatitude == null || endLongitude == null) return null;

    // Düzlem dönüşümü ile vektörler (CODES.md algoritması)
    final double xA = startLongitude, yA = startLatitude;
    final double xB = endLongitude!, yB = endLatitude!;
    final double xC = cLon, yC = cLat;

    final double abX = xB - xA;
    final double abY = yB - yA;
    final double acX = xC - xA;
    final double acY = yC - yA;

    // Nokta çarpımı ve AB vektörünün uzunluğunun karesi
    final double dotProduct = acX * abX + acY * abY;
    final double abLenSq = abX * abX + abY * abY;

    // İzdüşüm oranı (t) — clamping [0, 1]
    double t = (abLenSq != 0.0) ? dotProduct / abLenSq : 0.0;
    if (t < 0.0) t = 0.0;
    if (t > 1.0) t = 1.0;

    // İp üzerindeki en yakın P noktası
    final double pLat = yA + t * abY;
    final double pLon = xA + t * abX;

    return (pLat, pLon);
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
