import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  
  bool _isBoostMode = false;
  double _accuracyThreshold = 15.0; // Varsayılan doğruluk eşiği (metre)

  Stream<Position> get positionStream => _positionController.stream;
  bool get isBoostMode => _isBoostMode;
  double get accuracyThreshold => _accuracyThreshold;

  set accuracyThreshold(double value) {
    _accuracyThreshold = value;
  }

  /// Konum izinlerini kontrol eder ve ister.
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
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
  LocationSettings _getSettings() {
    if (_isBoostMode) {
      // J7 Prime için maksimum hassasiyet, sürekli güncelleme (Güç tüketimi yüksektir)
      return const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0, // Her hareketi algıla
        timeLimit: Duration(seconds: 10),
      );
    } else {
      // Normal/Pil Tasarrufu modu
      return const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 5, // 5 metrede bir güncelle
        timeLimit: Duration(seconds: 30),
      );
    }
  }

  /// Konumun doğruluk değerinin kabul edilebilir olup olmadığını kontrol eder.
  bool isAccuracyAcceptable(Position position) {
    return position.accuracy <= _accuracyThreshold;
  }

  /// Cihazın anlık tek seferlik konumunu alır.
  Future<Position> getCurrentPosition({bool forceHighAccuracy = false}) async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: forceHighAccuracy || _isBoostMode 
          ? LocationAccuracy.best 
          : LocationAccuracy.high,
    );
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
    _positionController.close();
  }
}
