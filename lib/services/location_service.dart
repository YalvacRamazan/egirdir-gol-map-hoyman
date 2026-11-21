import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionResult {
  final bool granted;
  final String reason;
  final bool isPermanentlyDenied;

  final bool isUnavailable;

  const LocationPermissionResult({
    required this.granted,
    required this.reason,
    this.isPermanentlyDenied = false,
    this.isUnavailable = false,
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
  double accuracyThreshold = 15.0;

  Future<bool> checkAndRequestPermission() async {
    final result = await checkAndRequestPermissionDetailed();
    return result.granted;
  }

  Future<LocationPermissionResult> checkAndRequestPermissionDetailed() async {
    try {
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
    } on MissingPluginException {
      return const LocationPermissionResult(
        granted: false,
        reason: 'Bu cihazda konum servisi desteklenmiyor.',
        isUnavailable: true,
      );
    }
  }

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

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  void toggleBoostMode(bool enable) {
    if (_isBoostMode == enable) return;
    _isBoostMode = enable;
    
    if (_positionStreamSubscription != null) {
      startTracking(boostMode: _isBoostMode);
    }
  }

  LocationSettings _getSettings() {
    if (_isBoostMode) {
      return const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      );
    } else {
      return const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 5,
      );
    }
  }

  bool isAccuracyAcceptable(Position position) {
    return position.accuracy <= accuracyThreshold;
  }

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
    _positionStreamSubscription = null;
  }
}
