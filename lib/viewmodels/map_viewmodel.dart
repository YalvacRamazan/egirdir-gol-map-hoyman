import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/services/battery_service.dart';
import 'package:map/services/compass_service.dart';
import 'package:map/services/database_service.dart';
import 'package:map/services/location_service.dart';
import 'package:map/services/persistent_backup_service.dart';
import 'package:map/services/settings_service.dart';
import 'package:map/viewmodels/proximity_policy.dart';

enum MapPointSelectionMode { none, selectA, selectB }

class MapViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final DatabaseService _dbService = DatabaseService();
  final LocationService _locationService = LocationService();
  final CompassService _compassService = CompassService();
  final SettingsService _settingsService = SettingsService();
  final BatteryService _batteryService = BatteryService();
  final PersistentBackupService _backupService = PersistentBackupService();

  List<BasketModel> _baskets = [];
  BasketModel? _activeBasket;
  BasketModel? _selectedBasket;

  Position? _currentPosition;
  bool _isPermissionGranted = false;
  bool _isTracking = false;
  bool _isInitializing = true;
  bool _hasInitialPosition = false;
  bool _isDisposed = false;
  String _gpsStatusText = 'GPS Başlatılmadı';
  bool _isGpsAccuracyGood = false;
  bool _isGpsError = false;
  bool _isLocationUnavailable = false;

  double? _currentHeading;
  bool _isCompassAvailable = false;
  bool _isCompassChecked = false;
  StreamSubscription<double>? _compassSubscription;

  String _permissionDeniedReason = '';
  bool _isPermissionPermanentlyDenied = false;

  StreamSubscription<Position>? _locationSubscription;

  MapPointSelectionMode _selectionMode = MapPointSelectionMode.none;

  bool _isFollowMode = false;

  static const List<double> proximityOptions = [10, 25, 50];
  bool _proximityAlertEnabled = true;
  final ProximityPolicy _proximityPolicy =
      ProximityPolicy(initialThreshold: 25.0);
  String? _proximityAlert;

  DateTime? _lastBatteryCheck;

  List<BasketModel> get baskets => _baskets;
  BasketModel? get activeBasket => _activeBasket;
  BasketModel? get selectedBasket => _selectedBasket;
  Position? get currentPosition => _currentPosition;
  bool get isPermissionGranted => _isPermissionGranted;
  bool get isTracking => _isTracking;
  bool get isBoostMode => _locationService.isBoostMode;
  bool get isInitializing => _isInitializing;
  bool get hasInitialPosition => _hasInitialPosition;
  String get gpsStatusText => _gpsStatusText;
  bool get isGpsAccuracyGood => _isGpsAccuracyGood;
  bool get isGpsError => _isGpsError;
  bool get isLocationUnavailable => _isLocationUnavailable;
  double get accuracyThreshold => _locationService.accuracyThreshold;
  String get permissionDeniedReason => _permissionDeniedReason;
  bool get isPermissionPermanentlyDenied => _isPermissionPermanentlyDenied;
  MapPointSelectionMode get selectionMode => _selectionMode;
  bool get isFollowMode => _isFollowMode;
  String? get proximityAlert => _proximityAlert;
  bool get isAutoBoostEnabled => _settingsService.settings.autoBoostEnabled;

  double? get currentHeading => _currentHeading;

  bool get isCompassAvailable => _isCompassAvailable;

  bool get isCompassUnavailable => _isCompassChecked && !_isCompassAvailable;

  double? get targetBearing => (selectedBasket ?? activeBasket)?.initialBearing;

  double? get requiredRotation =>
      (selectedBasket ?? activeBasket)?.initialBearingFrom(_currentHeading);

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _startCompass();

    configureProximity(
      enabled: _settingsService.settings.proximityAlertEnabled,
      threshold: _settingsService.settings.proximityThreshold,
    );

    try {
      await _restoreFromBackupIfEmpty();
      await loadBaskets();

      final activeList = await _dbService.getActiveBaskets();
      if (activeList.isNotEmpty) {
        _activeBasket = activeList.first;
      }

      if (_activeBasket == null && _baskets.isNotEmpty) {
        final lastCompleted = _baskets.where((b) => b.isCompleted).toList();
        if (lastCompleted.isNotEmpty) {
          _selectedBasket = lastCompleted.first;
        }
      }

      final permResult =
          await _locationService.checkAndRequestPermissionDetailed();
      _isPermissionGranted = permResult.granted;

      if (_isPermissionGranted) {
        startLocationTracking();
      } else if (permResult.isUnavailable) {
        _isLocationUnavailable = true;
        _gpsStatusText = 'Konum bu cihazda desteklenmiyor';
      } else {
        _permissionDeniedReason = permResult.reason;
        _isPermissionPermanentlyDenied = permResult.isPermanentlyDenied;
        _gpsStatusText = 'GPS İzni Verilmedi';
      }

      await _applyBatteryPolicy();
    } catch (e, stack) {
      debugPrint('MapViewModel.init() başlatma hatası: $e\n$stack');
      _gpsStatusText = 'Başlatma hatası: $e';
      _isGpsError = true;
    }

    _isInitializing = false;
    _safeNotify();
  }

  Future<bool> retryPermission() async {
    final permResult =
        await _locationService.checkAndRequestPermissionDetailed();
    _isPermissionGranted = permResult.granted;
    _permissionDeniedReason = permResult.reason;
    _isPermissionPermanentlyDenied = permResult.isPermanentlyDenied;
    _isLocationUnavailable = permResult.isUnavailable;

    if (_isPermissionGranted) {
      startLocationTracking();
    } else if (_isLocationUnavailable) {
      _gpsStatusText = 'Konum bu cihazda desteklenmiyor';
    } else {
      _gpsStatusText = 'GPS İzni Verilmedi';
    }
    _safeNotify();
    return _isPermissionGranted;
  }

  Future<void> loadBaskets() async {
    _baskets = await _dbService.getAllBaskets();
    _safeNotify();
  }

  void startLocationTracking() {
    _isTracking = true;
    _isGpsError = false;
    _locationService.startTracking(boostMode: _locationService.isBoostMode);

    _locationSubscription?.cancel();
    _locationSubscription = _locationService.positionStream.listen(
      (Position position) {
        _currentPosition = position;

        if (!_hasInitialPosition) {
          _hasInitialPosition = true;
        }

        _isGpsAccuracyGood = _locationService.isAccuracyAcceptable(position);
        _isGpsError = false;
        _gpsStatusText =
            'GPS Aktif (Hassasiyet: ${position.accuracy.toStringAsFixed(1)}m)';
        _checkProximity(position);
        unawaited(_applyBatteryPolicy());
        _safeNotify();
      },
      onError: (error) {
        _gpsStatusText = 'GPS Hatası: $error';
        _isGpsAccuracyGood = false;
        _isGpsError = true;
        _safeNotify();
      },
    );
  }

  void stopLocationTracking() {
    _isTracking = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopTracking();
    _gpsStatusText = 'GPS Durduruldu';
    _safeNotify();
  }

  void toggleBoostMode(bool enable) {
    _locationService.toggleBoostMode(enable);
    if (_isTracking) {
      startLocationTracking();
    }
    _safeNotify();
  }

  void setFollowMode(bool enable) {
    if (_isFollowMode == enable) return;
    _isFollowMode = enable;
    _safeNotify();
  }

  /// Uzaklık çizgisi ve yakınlık uyarısı için ortak hedef nokta.
  /// Aktif kayıtta A noktası; tamamlanmış sepette mesafe olarak en yakın uç.
  ({double lat, double lon, bool isStart})? resolveTargetPoint(Position? pos) {
    if (pos == null) return null;
    return targetPointForBasket(
      _selectedBasket ?? _activeBasket,
      pos.latitude,
      pos.longitude,
    );
  }

  double? distanceToTarget(Position? pos) {
    final target = resolveTargetPoint(pos);
    if (target == null || pos == null) return null;
    return _distanceBetween(pos, target.lat, target.lon);
  }

  double _distanceBetween(Position pos, double lat, double lon) {
    const calc = Distance();
    return calc.distance(
      LatLng(pos.latitude, pos.longitude),
      LatLng(lat, lon),
    );
  }

  void configureProximity({required bool enabled, required double threshold}) {
    _proximityAlertEnabled = enabled;
    _proximityPolicy.configure(threshold: threshold);
    _safeNotify();
  }

  void clearProximityAlert() {
    if (_proximityAlert == null) return;
    _proximityAlert = null;
    _safeNotify();
  }

  void _checkProximity(Position position) {
    final alert = _proximityPolicy.evaluate(
      enabled: _proximityAlertEnabled,
      basket: _selectedBasket ?? _activeBasket,
      lat: position.latitude,
      lon: position.longitude,
      now: DateTime.now(),
    );
    if (alert == null) return;
    _proximityAlert = alert;
    _safeNotify();
  }

  Future<void> _applyBatteryPolicy() async {
    if (!_settingsService.settings.autoBoostEnabled) return;
    final now = DateTime.now();
    if (_lastBatteryCheck != null &&
        now.difference(_lastBatteryCheck!) < const Duration(seconds: 30)) {
      return;
    }
    _lastBatteryCheck = now;

    final shouldBoost = await _batteryService.shouldUseBoost();
    if (_isDisposed) return;
    if (shouldBoost != _locationService.isBoostMode) {
      _locationService.toggleBoostMode(shouldBoost);
      if (_isTracking) startLocationTracking();
      _safeNotify();
    }
  }

  Future<void> _syncBackup() async {
    await _backupService.exportAll(_baskets);
  }

  Future<void> _restoreFromBackupIfEmpty() async {
    final existing = await _dbService.getAllBaskets();
    if (existing.isNotEmpty) return;
    final backup = await _backupService.loadBackup();
    if (backup.isEmpty) return;
    await _dbService.restoreBaskets(backup);
  }

  void updateAccuracyThreshold(double value) {
    _locationService.accuracyThreshold = value;
    if (_currentPosition != null) {
      _isGpsAccuracyGood =
          _locationService.isAccuracyAcceptable(_currentPosition!);
    }
    _safeNotify();
  }

  Future<bool> startRecordingBasket(String name, {String? startName}) async {
    if (_currentPosition == null) return false;

    final newBasket = BasketModel(
      name: name,
      startName: startName,
      startLatitude: _currentPosition!.latitude,
      startLongitude: _currentPosition!.longitude,
      startTimestamp: DateTime.now(),
      isCompleted: false,
    );

    final id = await _dbService.insertBasket(newBasket);
    _activeBasket = newBasket.copyWith(id: id);
    _selectedBasket = _activeBasket;

    await loadBaskets();
    await _syncBackup();
    _safeNotify();
    return true;
  }

  Future<BasketModel?> stopRecordingBasket({String? endName}) async {
    if (_activeBasket == null || _currentPosition == null) return null;

    final completedBasket = _activeBasket!.copyWith(
      endLatitude: _currentPosition!.latitude,
      endLongitude: _currentPosition!.longitude,
      endTimestamp: DateTime.now(),
      isCompleted: true,
      endName: endName,
    );

    await _dbService.updateBasket(completedBasket);
    _activeBasket = null;
    _selectedBasket = completedBasket;

    await loadBaskets();
    await _syncBackup();
    _safeNotify();
    return completedBasket;
  }

  void startSelectingA() {
    _selectionMode = (_selectionMode == MapPointSelectionMode.selectA)
        ? MapPointSelectionMode.none
        : MapPointSelectionMode.selectA;
    _safeNotify();
  }

  void startSelectingB() {
    _selectionMode = (_selectionMode == MapPointSelectionMode.selectB)
        ? MapPointSelectionMode.none
        : MapPointSelectionMode.selectB;
    _safeNotify();
  }

  void cancelSelection() {
    if (_selectionMode == MapPointSelectionMode.none) return;
    _selectionMode = MapPointSelectionMode.none;
    _safeNotify();
  }

  Future<bool> setPointA(LatLng point, {String? startName}) async {
    _selectionMode = MapPointSelectionMode.none;

    if (_activeBasket != null) {
      final updated = _activeBasket!.copyWith(
        startLatitude: point.latitude,
        startLongitude: point.longitude,
        startName: startName,
      );
      if (updated.id != null) {
        await _dbService.updateBasket(updated);
      }
      _activeBasket = updated;
      _selectedBasket = updated;
    } else {
      final newBasket = BasketModel(
        name: 'Sepet #${_baskets.length + 1}',
        startName: startName,
        startLatitude: point.latitude,
        startLongitude: point.longitude,
        startTimestamp: DateTime.now(),
      );
      final id = await _dbService.insertBasket(newBasket);
      _activeBasket = newBasket.copyWith(id: id);
      _selectedBasket = _activeBasket;
    }

    await loadBaskets();
    await _syncBackup();
    _safeNotify();
    return true;
  }

  Future<BasketModel?> setPointB(LatLng point, {String? endName}) async {
    if (_activeBasket == null) {
      _selectionMode = MapPointSelectionMode.none;
      _safeNotify();
      return null;
    }

    _selectionMode = MapPointSelectionMode.none;

    final completedBasket = _activeBasket!.copyWith(
      endLatitude: point.latitude,
      endLongitude: point.longitude,
      endTimestamp: DateTime.now(),
      isCompleted: true,
      endName: endName,
    );

    await _dbService.updateBasket(completedBasket);
    _activeBasket = null;
    _selectedBasket = completedBasket;

    await loadBaskets();
    await _syncBackup();
    _safeNotify();
    return completedBasket;
  }

  Future<void> renamePointA(String name, {int? basketId}) async {
    final target = _resolveRenameTarget(basketId);
    if (target == null) return;
    final updated = target.copyWith(startName: name);
    if (updated.id != null) {
      await _dbService.updateBasket(updated);
    }
    if (_activeBasket?.id == updated.id) _activeBasket = updated;
    if (_selectedBasket?.id == updated.id) _selectedBasket = updated;
    await loadBaskets();
    await _syncBackup();
    _safeNotify();
  }

  Future<void> renamePointB(String name, {int? basketId}) async {
    final target = _resolveRenameTarget(basketId);
    if (target == null) return;
    final updated = target.copyWith(endName: name);
    if (updated.id != null) {
      await _dbService.updateBasket(updated);
    }
    if (_activeBasket?.id == updated.id) _activeBasket = updated;
    if (_selectedBasket?.id == updated.id) _selectedBasket = updated;
    await loadBaskets();
    await _syncBackup();
    _safeNotify();
  }

  BasketModel? _resolveRenameTarget(int? basketId) {
    if (basketId != null) {
      if (_activeBasket?.id == basketId) return _activeBasket;
      if (_selectedBasket?.id == basketId) return _selectedBasket;
      for (final b in _baskets) {
        if (b.id == basketId) return b;
      }
      return null;
    }
    return _selectedBasket ?? _activeBasket;
  }

  Future<void> cancelRecording() async {
    if (_activeBasket != null && _activeBasket!.id != null) {
      await _dbService.deleteBasket(_activeBasket!.id!);
      _activeBasket = null;
      _selectedBasket = null;
      await loadBaskets();
      await _syncBackup();
      _safeNotify();
    }
  }

  void selectBasket(BasketModel? basket) {
    _selectedBasket = basket;
    _safeNotify();
  }

  Future<void> deleteBasket(int id) async {
    await _dbService.deleteBasket(id);
    if (_selectedBasket?.id == id) {
      _selectedBasket = null;
    }
    if (_activeBasket?.id == id) {
      _activeBasket = null;
    }
    await loadBaskets();
    await _syncBackup();
    _safeNotify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isPermissionGranted && !_isTracking) {
        startLocationTracking();
      }
      _startCompass();
      unawaited(_applyBatteryPolicy());
    } else if (state == AppLifecycleState.paused) {
      if (_activeBasket == null && _isTracking) {
        stopLocationTracking();
      }
      _compassService.stop();
    }
  }

  void _startCompass() {
    _compassService.start();
    _compassSubscription?.cancel();
    _compassSubscription = _compassService.headings.listen(
      (double heading) {
        _currentHeading = heading;
        _isCompassAvailable = true;
        _isCompassChecked = true;
        _safeNotify();
      },
      onError: (Object error) {
        debugPrint('Pusula akış hatası: $error');
        _isCompassAvailable = false;
        _isCompassChecked = true;
        _safeNotify();
      },
    );
    _compassService.isAvailable.addListener(_onCompassAvailabilityChanged);
  }

  void _onCompassAvailabilityChanged() {
    if (!_compassService.isAvailable.value) {
      _isCompassAvailable = false;
      _isCompassChecked = true;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _compassService.isAvailable.removeListener(_onCompassAvailabilityChanged);
    _compassSubscription?.cancel();
    _compassService.dispose();
    _locationSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
