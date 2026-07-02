import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/services/database_service.dart';
import 'package:map/services/location_service.dart';

class MapViewModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final LocationService _locationService = LocationService();

  List<BasketModel> _baskets = [];
  BasketModel? _activeBasket; // Şu an kaydedilmekte olan sepet (A noktası alındı, B bekleniyor)
  BasketModel? _selectedBasket; // Haritada gösterilmek üzere katalogdan seçilen sepet
  
  Position? _currentPosition;
  bool _isPermissionGranted = false;
  bool _isTracking = false;
  String _gpsStatusText = "GPS Başlatılmadı";
  bool _isGpsAccuracyGood = false;

  StreamSubscription<Position>? _locationSubscription;

  // Getter'lar
  List<BasketModel> get baskets => _baskets;
  BasketModel? get activeBasket => _activeBasket;
  BasketModel? get selectedBasket => _selectedBasket;
  Position? get currentPosition => _currentPosition;
  bool get isPermissionGranted => _isPermissionGranted;
  bool get isTracking => _isTracking;
  bool get isBoostMode => _locationService.isBoostMode;
  String get gpsStatusText => _gpsStatusText;
  bool get isGpsAccuracyGood => _isGpsAccuracyGood;
  double get accuracyThreshold => _locationService.accuracyThreshold;

  /// İlk kurulum ve verileri yükleme
  Future<void> init() async {
    await loadBaskets();
    
    // Aktif (yarım kalmış) sepet varsa yükle
    final activeList = await _dbService.getActiveBaskets();
    if (activeList.isNotEmpty) {
      _activeBasket = activeList.first;
    }

    // İzinleri kontrol et ve konumu başlat
    _isPermissionGranted = await _locationService.checkAndRequestPermission();
    if (_isPermissionGranted) {
      startLocationTracking();
    } else {
      _gpsStatusText = "GPS İzni Verilmedi";
      notifyListeners();
    }
  }

  /// Tüm sepetleri veritabanından yükler
  Future<void> loadBaskets() async {
    _baskets = await _dbService.getAllBaskets();
    notifyListeners();
  }

  /// Konum takibini başlatır
  void startLocationTracking() {
    _isTracking = true;
    _locationService.startTracking(boostMode: _locationService.isBoostMode);
    
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.positionStream.listen(
      (Position position) {
        _currentPosition = position;
        _isGpsAccuracyGood = _locationService.isAccuracyAcceptable(position);
        _gpsStatusText = "GPS Aktif (Hassasiyet: ${position.accuracy.toStringAsFixed(1)}m)";
        notifyListeners();
      },
      onError: (error) {
        _gpsStatusText = "GPS Hatası: $error";
        _isGpsAccuracyGood = false;
        notifyListeners();
      },
    );
  }

  /// Konum takibini durdurur (Pil tasarrufu için)
  void stopLocationTracking() {
    _isTracking = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopTracking();
    _gpsStatusText = "GPS Durduruldu";
    notifyListeners();
  }

  /// Boost modunu açar/kapatır
  void toggleBoostMode(bool enable) {
    _locationService.toggleBoostMode(enable);
    if (_isTracking) {
      // Takip aktifse yeni ayarlarla yeniden başlatılır
      startLocationTracking();
    }
    notifyListeners();
  }

  /// GPS doğruluk tolerans eşiğini günceller
  void updateAccuracyThreshold(double value) {
    _locationService.accuracyThreshold = value;
    if (_currentPosition != null) {
      _isGpsAccuracyGood = _locationService.isAccuracyAcceptable(_currentPosition!);
    }
    notifyListeners();
  }

  /// A Noktasını kaydeder (Sepet kaydını başlatır)
  Future<bool> startRecordingBasket(String name) async {
    if (_currentPosition == null) return false;

    // Doğruluk kontrolü (Boost modu kapalıyken sinyal zayıfsa uyarabiliriz)
    if (!_isGpsAccuracyGood) {
      // Kullanıcıya yine de kaydetmek isteyip istemediği sorulabilir,
      // ancak varsayılan olarak doğruluğu zorunlu kılmak güvenlik/doğruluk için iyidir.
    }

    final newBasket = BasketModel(
      name: name,
      startLatitude: _currentPosition!.latitude,
      startLongitude: _currentPosition!.longitude,
      startTimestamp: DateTime.now(),
      isCompleted: false,
    );

    final id = await _dbService.insertBasket(newBasket);
    _activeBasket = newBasket.copyWith(id: id);
    _selectedBasket = _activeBasket; // Kaydedilen sepeti haritada göster
    
    await loadBaskets();
    notifyListeners();
    return true;
  }

  /// B Noktasını kaydeder (Sepet kaydını tamamlar)
  Future<BasketModel?> stopRecordingBasket() async {
    if (_activeBasket == null || _currentPosition == null) return null;

    final completedBasket = _activeBasket!.copyWith(
      endLatitude: _currentPosition!.latitude,
      endLongitude: _currentPosition!.longitude,
      endTimestamp: DateTime.now(),
      isCompleted: true,
    );

    await _dbService.updateBasket(completedBasket);
    _activeBasket = null;
    _selectedBasket = completedBasket; // Tamamlanan sepeti haritada göster

    await loadBaskets();
    notifyListeners();
    return completedBasket;
  }

  /// Aktif sepet kaydını iptal eder
  Future<void> cancelRecording() async {
    if (_activeBasket != null && _activeBasket!.id != null) {
      await _dbService.deleteBasket(_activeBasket!.id!);
      _activeBasket = null;
      _selectedBasket = null;
      await loadBaskets();
      notifyListeners();
    }
  }

  /// Haritada gösterilecek sepeti seçer (Katalogdan tıklanınca)
  void selectBasket(BasketModel? basket) {
    _selectedBasket = basket;
    notifyListeners();
  }

  /// Bir sepeti siler
  Future<void> deleteBasket(int id) async {
    await _dbService.deleteBasket(id);
    if (_selectedBasket?.id == id) {
      _selectedBasket = null;
    }
    if (_activeBasket?.id == id) {
      _activeBasket = null;
    }
    await loadBaskets();
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
