import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/services/database_service.dart';
import 'package:map/services/location_service.dart';
import 'package:map/services/sqlite_tile_cache_service.dart';

class MapViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final DatabaseService _dbService = DatabaseService();
  final LocationService _locationService = LocationService();

  List<BasketModel> _baskets = [];
  BasketModel? _activeBasket; // Şu an kaydedilmekte olan sepet (A noktası alındı, B bekleniyor)
  BasketModel? _selectedBasket; // Haritada gösterilmek üzere katalogdan seçilen sepet

  Position? _currentPosition;
  bool _isPermissionGranted = false;
  bool _isTracking = false;
  bool _isInitializing = true; // Başlangıç yüklemesi tamamlanmadı mı?
  bool _hasInitialPosition = false; // İlk konum alındı mı? (haritayı otomatik götürmek için)
  bool _isDisposed = false; // dispose() sonrası notifyListeners() hatasını önler
  String _gpsStatusText = 'GPS Başlatılmadı';
  bool _isGpsAccuracyGood = false;

  // İzin reddedilince kullanıcıya mesaj / ayarlara yönlendirme
  String _permissionDeniedReason = '';
  bool _isPermissionPermanentlyDenied = false;

  StreamSubscription<Position>? _locationSubscription;

  // Getter'lar
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
  double get accuracyThreshold => _locationService.accuracyThreshold;
  String get permissionDeniedReason => _permissionDeniedReason;
  bool get isPermissionPermanentlyDenied => _isPermissionPermanentlyDenied;

  /// İlk kurulum ve verileri yükleme
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    // SQLite harita önbelleğini başlat
    await SqliteTileCacheService().init();

    await loadBaskets();

    // Aktif (yarım kalmış) sepet varsa yükle
    final activeList = await _dbService.getActiveBaskets();
    if (activeList.isNotEmpty) {
      _activeBasket = activeList.first;
    }

    // İzinleri kontrol et ve konumu başlat
    final permResult = await _locationService.checkAndRequestPermissionDetailed();
    _isPermissionGranted = permResult.granted;

    if (_isPermissionGranted) {
      startLocationTracking();
    } else {
      _permissionDeniedReason = permResult.reason;
      _isPermissionPermanentlyDenied = permResult.isPermanentlyDenied;
      _gpsStatusText = 'GPS İzni Verilmedi';
    }

    _isInitializing = false;
    _safeNotify();
  }

  /// İzni tekrar istemek için (permission overlay'deki "Yeniden Dene" butonundan çağrılır)
  Future<bool> retryPermission() async {
    final permResult =
        await _locationService.checkAndRequestPermissionDetailed();
    _isPermissionGranted = permResult.granted;
    _permissionDeniedReason = permResult.reason;
    _isPermissionPermanentlyDenied = permResult.isPermanentlyDenied;

    if (_isPermissionGranted) {
      startLocationTracking();
    } else {
      _gpsStatusText = 'GPS İzni Verilmedi';
    }
    _safeNotify();
    return _isPermissionGranted;
  }

  /// Tüm sepetleri veritabanından yükler
  Future<void> loadBaskets() async {
    _baskets = await _dbService.getAllBaskets();
    _safeNotify();
  }

  /// Konum takibini başlatır
  void startLocationTracking() {
    _isTracking = true;
    _locationService.startTracking(boostMode: _locationService.isBoostMode);

    _locationSubscription?.cancel();
    _locationSubscription = _locationService.positionStream.listen(
      (Position position) {
        _currentPosition = position;

        // İlk konum alındığında flag set et (harita bu konuma hareket edecek)
        if (!_hasInitialPosition) {
          _hasInitialPosition = true;
        }

        _isGpsAccuracyGood = _locationService.isAccuracyAcceptable(position);
        _gpsStatusText =
            'GPS Aktif (Hassasiyet: ${position.accuracy.toStringAsFixed(1)}m)';
        _safeNotify();
      },
      onError: (error) {
        _gpsStatusText = 'GPS Hatası: $error';
        _isGpsAccuracyGood = false;
        _safeNotify();
      },
    );
  }

  /// Konum takibini durdurur (Pil tasarrufu için)
  void stopLocationTracking() {
    _isTracking = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopTracking();
    _gpsStatusText = 'GPS Durduruldu';
    _safeNotify();
  }

  /// Boost modunu açar/kapatır
  void toggleBoostMode(bool enable) {
    _locationService.toggleBoostMode(enable);
    if (_isTracking) {
      // Takip aktifse yeni ayarlarla yeniden başlatılır
      startLocationTracking();
    }
    _safeNotify();
  }

  /// GPS doğruluk tolerans eşiğini günceller
  void updateAccuracyThreshold(double value) {
    _locationService.accuracyThreshold = value;
    if (_currentPosition != null) {
      _isGpsAccuracyGood =
          _locationService.isAccuracyAcceptable(_currentPosition!);
    }
    _safeNotify();
  }

  /// A Noktasını kaydeder (Sepet kaydını başlatır)
  Future<bool> startRecordingBasket(String name) async {
    if (_currentPosition == null) return false;

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
    _safeNotify();
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
    _safeNotify();
    return completedBasket;
  }

  /// Aktif sepet kaydını iptal eder
  Future<void> cancelRecording() async {
    if (_activeBasket != null && _activeBasket!.id != null) {
      await _dbService.deleteBasket(_activeBasket!.id!);
      _activeBasket = null;
      _selectedBasket = null;
      await loadBaskets();
      _safeNotify();
    }
  }

  /// Haritada gösterilecek sepeti seçer (Katalogdan tıklanınca)
  void selectBasket(BasketModel? basket) {
    _selectedBasket = basket;
    _safeNotify();
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
    _safeNotify();
  }

  // --- AppLifecycleObserver ---
  // Uygulama arka plana geçtiğinde GPS stream'ini kapatmıyoruz:
  // Eğer aktif bir sepet kaydı varsa konumu yitirmemek için stream açık kalır.
  // Ön plana dönünce UI zaten stream'den güncellenir.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Uygulama ön plana geldi: eğer izin verilmiş ama tracking durmuşsa yeniden başlat
      if (_isPermissionGranted && !_isTracking) {
        startLocationTracking();
      }
    } else if (state == AppLifecycleState.paused) {
      // Aktif kayıt YOKSA pil tasarrufu için GPS'i durdur
      if (_activeBasket == null && _isTracking) {
        stopLocationTracking();
      }
      // Aktif kayıt VARSA durdurmuyoruz — kayıt devam etmeli
    }
  }

  /// notifyListeners() güvenli sürümü — dispose sonrası çağrılmaz
  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
