import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Konum izni durumunu açıklayan sonuç sınıfı
class LocationPermissionResult {
  final bool granted;
  final String reason; // kullanıcıya gösterilecek açıklama
  final bool isPermanentlyDenied;

  const LocationPermissionResult({
    required this.granted,
    required this.reason,
    this.isPermanentlyDenied = false,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  
  bool _isBoostMode = false;
  Stream<Position> get positionStream => _positionController.stream;
  bool get isBoostMode => _isBoostMode;
  // accuracyThreshold doğrudan alan olarak tutulur (gereksiz getter/setter önlenir)
  double accuracyThreshold = 15.0; // Varsayılan doğruluk eşiği (metre)

  /// Konum izinlerini kontrol eder ve ister.
  /// Detaylı sonuç için [checkAndRequestPermissionDetailed] kullanın.
  Future<bool> checkAndRequestPermission() async {
    final result = await checkAndRequestPermissionDetailed();
    return result.granted;
  }

  /// Konum izinlerini kontrol eder; ret nedenini de döner.
  Future<LocationPermissionResult> checkAndRequestPermissionDetailed() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationPermissionResult(
        granted: false,
        reason: 'GPS/Konum servisi kapalı. Lütfen cihazınızın konum ayarlarını açın.',
      );
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationPermissionResult(
          granted: false,
          reason: 'Konum izni reddedildi. Harita özelliklerini kullanmak için izin gereklidir.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationPermissionResult(
        granted: false,
        reason: 'Konum izni kalıcı olarak engellendi. Lütfen Ayarlar → Uygulama İzinleri bölümünden izin verin.',
        isPermanentlyDenied: true,
      );
    }

    return const LocationPermissionResult(
      granted: true,
      reason: '',
    );
  }

  /// Konum takibini başlatır.
  void startTracking({bool boostMode = false}) {
    _isBoostMode = boostMode;
    _positionStreamSubscription?.cancel();

    final LocationSettings locationSettings = _getSettings();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _positionController.add(position);
      },
      onError: (error) {
        _positionController.addError(error);
      },
    );
  }

  /// Konum takibini durdurur.
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Boost Modunu (Yüksek Hassasiyet) açar veya kapatır.
  void toggleBoostMode(bool enable) {
    if (_isBoostMode == enable) return;
    _isBoostMode = enable;
    
    // Aktif takip varsa yeni ayarlarla yeniden başlatır
    if (_positionStreamSubscription != null) {
      startTracking(boostMode: _isBoostMode);
    }
  }

  /// Ayarları Boost veya Normal moduna göre belirler.
  /// Not: timeLimit kullanılmıyor — aksi takdirde stream sürekli kapanıp yeniden açılır.
  LocationSettings _getSettings() {
    if (_isBoostMode) {
      // J7 Prime için maksimum hassasiyet, sürekli güncelleme (Güç tüketimi yüksektir)
      return const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0, // Her hareketi algıla
      );
    } else {
      // Normal/Pil Tasarrufu modu
      return const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 5, // 5 metrede bir güncelle
      );
    }
  }

  /// Konumun doğruluk değerinin kabul edilebilir olup olmadığını kontrol eder.
  bool isAccuracyAcceptable(Position position) {
    return position.accuracy <= accuracyThreshold;
  }

  /// Cihazın anlık tek seferlik konumunu alır.
  Future<Position> getCurrentPosition({bool forceHighAccuracy = false}) async {
    final accuracy = (forceHighAccuracy || _isBoostMode)
        ? LocationAccuracy.best
        : LocationAccuracy.high;
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy),
    );
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
    _positionController.close();
  }
}
