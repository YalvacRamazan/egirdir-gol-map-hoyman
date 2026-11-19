import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/services/compass_service.dart';
import 'package:map/services/database_service.dart';
import 'package:map/services/location_service.dart';
import 'package:map/services/sqlite_tile_cache_service.dart';

/// Harita üzerinde nokta seçim modu.
/// [none]: seçim yok, harita dokunuşları serbest kaydırma/zoom.
/// [selectA] / [selectB]: sıradaki harita dokunuşu A/B noktası olarak alınır.
enum MapPointSelectionMode { none, selectA, selectB }

class MapViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final DatabaseService _dbService = DatabaseService();
  final LocationService _locationService = LocationService();
  final CompassService _compassService = CompassService();

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
  bool _isGpsError = false; // Konum akışında hata oluştu mu?
  bool _isLocationUnavailable = false; // Platform konum servisini hiç desteklemiyor mu?

  // Pusula (cihazın baktığı yön) durumu
  double? _currentHeading; // null: henüz veri yok / sensör yok
  bool _isCompassAvailable = false; // Sensör kullanılabilir mi?
  bool _isCompassChecked = false; // Sensör durumu tespit edildi mi?
  StreamSubscription<double>? _compassSubscription;

  // İzin reddedilince kullanıcıya mesaj / ayarlara yönlendirme
  String _permissionDeniedReason = '';
  bool _isPermissionPermanentlyDenied = false;

  StreamSubscription<Position>? _locationSubscription;

  // Haritadan A/B noktası seçim modu (birincil nokta seçim akışı)
  MapPointSelectionMode _selectionMode = MapPointSelectionMode.none;

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
  bool get isGpsError => _isGpsError;
  bool get isLocationUnavailable => _isLocationUnavailable;
  double get accuracyThreshold => _locationService.accuracyThreshold;
  String get permissionDeniedReason => _permissionDeniedReason;
  bool get isPermissionPermanentlyDenied => _isPermissionPermanentlyDenied;
  MapPointSelectionMode get selectionMode => _selectionMode;

  /// Cihazın baktığı yön (derece, 0=K, saat yönü). Sensör yoksa null.
  double? get currentHeading => _currentHeading;

  /// Pusula sensörü kullanılabilir mi? (ilk tespit sonrası güvenilir)
  bool get isCompassAvailable => _isCompassAvailable;

  /// Pusula sensörü kullanılamıyor mu? (tespit edildi + kullanılamıyor)
  bool get isCompassUnavailable => _isCompassChecked && !_isCompassAvailable;

  /// Haritada gösterilecek sepetin A→B hedef yönü (derece).
  /// Sepet yok veya B noktası yoksa null.
  double? get targetBearing => (selectedBasket ?? activeBasket)?.initialBearing;

  /// Kullanıcının baktığı yönden hedef yöne en kısa dönüş açısı.
  /// Pozitif: saat yönü (sağa), negatif: saat yönünün tersine (sola).
  /// Heading veya hedef yön yoksa null.
  double? get requiredRotation =>
      (selectedBasket ?? activeBasket)?.initialBearingFrom(_currentHeading);

  /// İlk kurulum ve verileri yükleme
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _startCompass();

    try {
      // SQLite harita önbelleğini başlat
      await SqliteTileCacheService().init();

      await loadBaskets();

      // Aktif (yarım kalmış) sepet varsa yükle
      final activeList = await _dbService.getActiveBaskets();
      if (activeList.isNotEmpty) {
        _activeBasket = activeList.first;
      }

      // Aktif kayıt yoksa en son tamamlanmış sepeti otomatik seç
      // → Uygulama açılır açılmaz mesafe bilgisi görünsün
      if (_activeBasket == null && _baskets.isNotEmpty) {
        final lastCompleted = _baskets.where((b) => b.isCompleted).toList();
        if (lastCompleted.isNotEmpty) {
          _selectedBasket = lastCompleted.first;
        }
      }

      // İzinleri kontrol et ve konumu başlat
      final permResult =
          await _locationService.checkAndRequestPermissionDetailed();
      _isPermissionGranted = permResult.granted;

      if (_isPermissionGranted) {
        startLocationTracking();
      } else if (permResult.isUnavailable) {
        // Platform konumu hiç desteklemiyor (ör. Linux masaüstü):
        // hata değil, bilinen durum. Konumsuz modda sessizce devam et.
        _isLocationUnavailable = true;
        _gpsStatusText = 'Konum bu cihazda desteklenmiyor';
      } else {
        _permissionDeniedReason = permResult.reason;
        _isPermissionPermanentlyDenied = permResult.isPermanentlyDenied;
        _gpsStatusText = 'GPS İzni Verilmedi';
      }
    } catch (e, stack) {
      // Kök neden kaybolmasın: hatayı stack trace ile logla
      debugPrint('MapViewModel.init() başlatma hatası: $e\n$stack');
      _gpsStatusText = 'Başlatma hatası: $e';
      _isGpsError = true;
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

  /// Tüm sepetleri veritabanından yükler
  Future<void> loadBaskets() async {
    _baskets = await _dbService.getAllBaskets();
    _safeNotify();
  }

  /// Konum takibini başlatır
  void startLocationTracking() {
    _isTracking = true;
    _isGpsError = false;
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
        _isGpsError = false;
        _gpsStatusText =
            'GPS Aktif (Hassasiyet: ${position.accuracy.toStringAsFixed(1)}m)';
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

  /// A Noktasını kaydeder (Sepet kaydını başlatır).
  /// [startName] verilmezse model varsayılanı ("A Noktası") kullanılır.
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
    _selectedBasket = _activeBasket; // Kaydedilen sepeti haritada göster

    await loadBaskets();
    _safeNotify();
    return true;
  }

  /// B Noktasını kaydeder (Sepet kaydını tamamlar).
  /// [endName] verilmezse mevcut değer korunur (varsayılan: "B Noktası").
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
    _selectedBasket = completedBasket; // Tamamlanan sepeti haritada göster

    await loadBaskets();
    _safeNotify();
    return completedBasket;
  }

  // --- Haritadan Nokta Seçimi (birincil akış) ---

  /// "A noktası seç" modunu başlatır (aynı moddaysa iptal eder).
  void startSelectingA() {
    _selectionMode = (_selectionMode == MapPointSelectionMode.selectA)
        ? MapPointSelectionMode.none
        : MapPointSelectionMode.selectA;
    _safeNotify();
  }

  /// "B noktası seç" modunu başlatır (aynı moddaysa iptal eder).
  void startSelectingB() {
    _selectionMode = (_selectionMode == MapPointSelectionMode.selectB)
        ? MapPointSelectionMode.none
        : MapPointSelectionMode.selectB;
    _safeNotify();
  }

  /// Aktif seçim modunu iptal eder.
  void cancelSelection() {
    if (_selectionMode == MapPointSelectionMode.none) return;
    _selectionMode = MapPointSelectionMode.none;
    _safeNotify();
  }

  /// Haritada tıklanan noktayı A (başlangıç) yapar.
  /// Aktif sepet varsa onun A noktası güncellenir; yoksa yeni sepet başlatılır.
  /// [startName] null ise mevcut isim korunur (varsayılan: "A Noktası").
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
    _safeNotify();
    return true;
  }

  /// Haritada tıklanan noktayı B (bitiş) yapar ve sepeti tamamlar.
  /// Aktif sepet yoksa null döner (önce A noktası gerekir).
  /// [endName] null ise mevcut isim korunur (varsayılan: "B Noktası").
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
    _safeNotify();
    return completedBasket;
  }

  /// A noktasının adını değiştirir. [basketId] verilmezse haritada gösterilen
  /// (seçili veya aktif) sepet hedeflenir.
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
    _safeNotify();
  }

  /// B noktasının adını değiştirir. [basketId] verilmezse haritada gösterilen
  /// (seçili veya aktif) sepet hedeflenir.
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
    _safeNotify();
  }

  /// Yeniden adlandırma hedefini çözer: id verildiyse o sepet, yoksa
  /// haritada gösterilen sepet (seçili, yoksa aktif).
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
      // Pusula sensörü ön planda yeniden başlatılır
      _startCompass();
    } else if (state == AppLifecycleState.paused) {
      // Aktif kayıt YOKSA pil tasarrufu için GPS'i durdur
      if (_activeBasket == null && _isTracking) {
        stopLocationTracking();
      }
      // Aktif kayıt VARSA durdurmuyoruz: kayıt devam etmeli
      // Pusula: pil tasarrufu için arka planda her zaman durdurulur
      _compassService.stop();
    }
  }

  /// Pusula akışını başlatır ve heading güncellemelerini dinler.
  /// Sensör yoksa/hata olursa uygulamayı düşürmez; durumu bildirir.
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
    // Sensör yoksa (ilk olay timeout) durumu bildir
    _compassService.isAvailable.addListener(_onCompassAvailabilityChanged);
  }

  void _onCompassAvailabilityChanged() {
    if (!_compassService.isAvailable.value) {
      _isCompassAvailable = false;
      _isCompassChecked = true;
      _safeNotify();
    }
  }

  /// notifyListeners() güvenli sürümü: dispose sonrası çağrılmaz
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
