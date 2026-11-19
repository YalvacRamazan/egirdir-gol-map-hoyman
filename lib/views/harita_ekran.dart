import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/services/settings_service.dart';
import 'package:map/services/share_service.dart';
import 'package:map/services/sqlite_tile_provider.dart';
import 'package:map/theme/palette.dart';
import 'package:map/utils/bearing.dart';
import 'package:map/viewmodels/map_viewmodel.dart';
import 'package:map/views/ayarlar_ekran.dart';
import 'package:map/views/katalog_sayfasi.dart';

/// Hoyman Gölü merkezi: uygulama açılışında gösterilecek varsayılan konum
const LatLng _kHoymanGoluMerkezi = LatLng(38.10, 30.98);

class HaritaEkran extends StatefulWidget {
  const HaritaEkran({super.key});

  @override
  State<HaritaEkran> createState() => _HaritaEkranState();
}

class _HaritaEkranState extends State<HaritaEkran> {
  final MapViewModel _viewModel = MapViewModel();
  final MapController _mapController = MapController();
  final _settingsService = SettingsService();

  /// Tile provider yalnızca bir kez oluşturulur; her rebuild'de yeni bir
  /// HttpClient kurulup eskisinin atılmasını (kaynak churn) önler.
  final SqliteTileProvider _tileProvider = SqliteTileProvider();

  /// Aynı karede birden fazla ölçüm planlamasını önleyen guard
  bool _isMeasureScheduled = false;

  /// Alt panelin gerçek yüksekliğini ölçmek için (FAB çakışmasını önler)
  final GlobalKey _bottomPanelKey = GlobalKey();
  double _bottomPanelHeight = 0;

  /// Harita yalnızca bir kez otomatik kullanıcı konumuna taşınır
  bool _hasMovedToPosition = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.init().then((_) {
      // init() tamamlandıktan sonra "devam eden kayıt" kontrolü yap
      if (mounted && _viewModel.activeBasket != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showResumeRecordingDialog();
        });
      }
    });
  }

  /// ViewModel değiştiğinde haritayı ilk konuma yönlendir (yalnızca bir kez)
  void _onViewModelChanged() {
    if (!_hasMovedToPosition && _viewModel.hasInitialPosition &&
        _viewModel.currentPosition != null) {
      _hasMovedToPosition = true;
      final pos = _viewModel.currentPosition!;
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _mapController.dispose();
    _tileProvider.dispose();
    super.dispose();
  }

  /// Haritayı belirli bir konuma odaklar
  void _focusOnLocation(LatLng point, double zoom) {
    _mapController.move(point, zoom);
  }

  /// Alt panelin yüksekliğini ölçer ve FAB konumunu günceller.
  void _measureBottomPanel() {
    final ctx = _bottomPanelKey.currentContext;
    if (ctx == null) return;
    final h = ctx.size?.height ?? 0;
    if (h != _bottomPanelHeight && mounted) {
      setState(() => _bottomPanelHeight = h);
    }
  }

  /// Alt panel ölçümünü bir sonraki kareye planlar.
  /// Aynı karedeki tekrarlanan build'lerde yalnızca tek callback kaydedilir.
  void _scheduleBottomPanelMeasure() {
    if (_isMeasureScheduled) return;
    _isMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasureScheduled = false;
      _measureBottomPanel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final currentPos = _viewModel.currentPosition;
        final userLatLng = currentPos != null
            ? LatLng(currentPos.latitude, currentPos.longitude)
            : _kHoymanGoluMerkezi;

        // Haritada gösterilecek aktif veya seçili sepet
        final showBasket = _viewModel.selectedBasket ?? _viewModel.activeBasket;

        // Panel yüksekliği değiştiyse bir sonraki karede yeniden ölç
        _scheduleBottomPanelMeasure();

        return Scaffold(
          body: Stack(
            children: [
              // --- 1. HARİTA KATMANI (Tile, Polyline, Circle, Marker) ---
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _kHoymanGoluMerkezi,
                  initialZoom: 12.0,
                  maxZoom: 18.0,
                  minZoom: 6.0,
                  // Seçim modu aktifken dokunulan nokta A/B olarak alınır;
                  // mod yoksa dokunuş serbest kaydırma/zoom olarak davranır.
                  onTap: (tapPosition, point) => _onMapTap(point),
                ),
                children: [
                  // Harita Altlığı (Tile Layer) - SQLite Önbellek Desteği ile
                  // Görüntülenen tile'lar otomatik indirilip SQLite'a kaydedilir.
                  // Bir sonraki açılışta (offline dahil) doğrudan SQLite'tan okunur.
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rumata.gol_sepet_takip',
                    tileProvider: _tileProvider,
                  ),

                  // GPS Doğruluk Çemberi (Sadece GPS aktifse çizilir)
                  if (currentPos != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: userLatLng,
                          radius: currentPos.accuracy, // Metre cinsinden doğruluk yarıçapı
                          useRadiusInMeter: true,
                          // İyi doğruluk birincil, zayıf doğruluk uyarı vurgusudur.
                          color: _viewModel.isGpsAccuracyGood
                              ? Palette.primary.withValues(alpha: 0.15)
                              : Palette.accentWarning.withValues(alpha: 0.15),
                          borderColor: _viewModel.isGpsAccuracyGood
                              ? Palette.primary.withValues(alpha: 0.5)
                              : Palette.accentWarning.withValues(alpha: 0.5),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),

                  // Sepet Çizgisi (A -> B Arasındaki Çizgi)
                  if (showBasket != null &&
                      showBasket.endLatitude != null &&
                      showBasket.endLongitude != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            LatLng(showBasket.startLatitude,
                                showBasket.startLongitude),
                            LatLng(showBasket.endLatitude!,
                                showBasket.endLongitude!),
                          ],
                          strokeWidth: 4.0,
                          color: Palette.primary,
                        ),
                      ],
                    ),

                  // İşaretçiler (User, A Noktası, B Noktası)
                  MarkerLayer(
                    markers: [
                      // Kullanıcı Konumu İşaretçisi (heading varsa yön okuyla)
                      if (currentPos != null)
                        Marker(
                          point: userLatLng,
                          width: 44,
                          height: 44,
                          child: Semantics(
                            label: _viewModel.currentHeading != null
                                ? 'Kullanıcı konumu ve baktığı yön'
                                : 'Kullanıcı konumu',
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Baktığı yön oku: heading'e göre döner (0°=K, saat yönü)
                                if (_viewModel.currentHeading != null)
                                  Transform.rotate(
                                    angle: _viewModel.currentHeading! *
                                        math.pi /
                                        180,
                                    child: Icon(
                                      Icons.navigation,
                                      size: 40,
                                      color: Palette.userLocation,
                                      shadows: const [
                                        Shadow(
                                            color: Colors.white,
                                            blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Palette.userLocation,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Sepet Başlangıç (A) Noktası
                      if (showBasket != null)
                        Marker(
                          point: LatLng(showBasket.startLatitude,
                              showBasket.startLongitude),
                          width: 100,
                          height: 64,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            // Marker'a dokunmak isim düzenlemeyi açar
                            onTap: () => _promptPointName(
                              isStart: true,
                              initialName: showBasket.startName,
                              onConfirm: (name) => unawaited(
                                _viewModel.renamePointA(name,
                                    basketId: showBasket.id),
                              ),
                            ),
                            child: Semantics(
                              label:
                                  'Sepet başlangıç noktası (A): ${showBasket.startDisplayName}. Adını düzenlemek için dokunun.',
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Palette.pointA,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 2),
                                  _buildMarkerNameLabel(
                                    showBasket.startDisplayName,
                                    Palette.pointA,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Sepet Bitiş (B) Noktası
                      if (showBasket != null &&
                          showBasket.endLatitude != null &&
                          showBasket.endLongitude != null)
                        Marker(
                          point: LatLng(showBasket.endLatitude!,
                              showBasket.endLongitude!),
                          width: 100,
                          height: 64,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            // Marker'a dokunmak isim düzenlemeyi açar
                            onTap: () => _promptPointName(
                              isStart: false,
                              initialName: showBasket.endName,
                              onConfirm: (name) => unawaited(
                                _viewModel.renamePointB(name,
                                    basketId: showBasket.id),
                              ),
                            ),
                            child: Semantics(
                              label:
                                  'Sepet bitiş noktası (B): ${showBasket.endDisplayName}. Adını düzenlemek için dokunun.',
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.flag,
                                    color: Palette.pointB,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 2),
                                  _buildMarkerNameLabel(
                                    showBasket.endDisplayName,
                                    Palette.pointB,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // --- 1.5 OSM ATIF BİLGİSİ ---
                // DESIGN.md gereği harita üzerinde görünür olmalı.
                // Tıklanınca OSM telif sayfası açılır.
                RichAttributionWidget(
                  showFlutterMapAttribution: false,
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap katkıcıları',
                      onTap: () => unawaited(launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      )),
                    ),
                  ],
                ),
              ],
            ),

            // --- 2. ÜST BİLGİ VE KONTROL PANELİ ---
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    // GPS Durum Kartı
                    Expanded(
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                _viewModel.isGpsError
                                    ? Icons.gps_off
                                    : Icons.gps_fixed,
                                color: _gpsStatusColor(context),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _viewModel.gpsStatusText,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // GPS Boost Düğmesi (J7 Prime için hassas mod)
                    _buildRoundButton(
                      icon: Icons.flash_on,
                      color: _viewModel.isBoostMode
                          ? Palette.accentWarning
                          : Palette.neutralMuted,
                      iconColor: Colors.white,
                      tooltip: 'GPS Boost (Hassas Mod)',
                      onPressed: () {
                        _viewModel.toggleBoostMode(!_viewModel.isBoostMode);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _viewModel.isBoostMode
                                  ? 'Boost Modu Aktif (Yüksek Doğruluk, Yüksek Pil Tüketimi)'
                                  : 'Dengeli Mod Aktif (Pil Tasarrufu)',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Katalog Düğmesi
                    _buildRoundButton(
                      icon: Icons.list_alt,
                      color: Palette.primary,
                      iconColor: Colors.white,
                      tooltip: 'Sepet Kataloğu',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => KatalogSayfasi(
                              viewModel: _viewModel,
                              backupPhoneNumber:
                                  _settingsService.settings.backupPhoneNumber,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Ayarlar Düğmesi
                    _buildRoundButton(
                      icon: Icons.settings,
                      color: Palette.neutralStrong,
                      iconColor: Colors.white,
                      tooltip: 'Ayarlar',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AyarlarEkran(viewModel: _viewModel),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // --- 2.5 ÇEVRİMDIŞI ROZETİ ---
              // Tile provider'ın offline durumunu dinler: yalnızca ağ
              // denemesi başarısız olduğunda görünür, başarılı yüklemede
              // kaybolur. IgnorePointer sayesinde rozet harita kaydırma ve
              // zoom jestlerini engellemez.
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                left: 12,
                right: 12,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _tileProvider.offline,
                  builder: (context, isOffline, _) {
                    if (!isOffline) return const SizedBox.shrink();
                    return IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            // Vurgu rengi: çevrimdışı bir uyarı durumudur
                            // (DESIGN.md R-29). Beyaz metinle WCAG AA geçer.
                            color: Palette.accentWarning,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Çevrimdışı: önbellekteki alanlar gösteriliyor',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // --- 2.6 NOKTA SEÇİM YÖNERGESİ (seçim modu aktifken) ---
              if (_viewModel.selectionMode != MapPointSelectionMode.none)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 96,
                  left: 12,
                  right: 12,
                  child: _buildSelectionBanner(context),
                ),

              // --- 2.7 YÖN OKU (konum yoksa harita merkezinde) ---
              // GPS konumu yokken baktığı yön oku merkezde "Yön" etiketiyle
              // gösterilir; yanıltıcı konum iması yapılmaz.
              if (_viewModel.currentHeading != null && currentPos == null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.rotate(
                            angle:
                                _viewModel.currentHeading! * math.pi / 180,
                            child: Icon(
                              Icons.navigation,
                              size: 48,
                              color: Palette.userLocation,
                              shadows: const [
                                Shadow(color: Colors.white, blurRadius: 6),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Palette.userLocation, width: 1),
                            ),
                            child: const Text(
                              'Yön',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Palette.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // --- 2.8 CANLI PUSULA / SENSÖR DURUMU (sol alt) ---
              // FAB ve A/B butonları sağda olduğu için sol alt köşe çakışmaz.
              Positioned(
                bottom: _getBottomOffset(),
                left: 16,
                child: _buildCompassOverlay(context),
              ),

              // --- 3. HARİTA KONTROL ARAÇLARI (Konumuma Git) ---
              Positioned(
                bottom: _getBottomOffset(),
                right: 16,
                child: FloatingActionButton(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  tooltip: 'Konumuma Git',
                  onPressed: () {
                    if (currentPos != null) {
                      _focusOnLocation(userLatLng, 15.0);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Konumunuz henüz alınamadı.')),
                      );
                    }
                  },
                  child: const Icon(Icons.my_location),
                ),
              ),

              // --- 3.5 NOKTA SEÇİM KONTROLLERİ (A/B) ---
              Positioned(
                bottom: _getBottomOffset() + 64,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPointSelectButton(
                      letter: 'A',
                      icon: Icons.location_on,
                      color: Palette.pointA,
                      idleColor:
                          Palette.pointAFor(Theme.of(context).brightness),
                      tooltip: 'A noktası seç (haritaya dokun)',
                      isActive: _viewModel.selectionMode ==
                          MapPointSelectionMode.selectA,
                      onPressed: () => _startSelection(isStart: true),
                    ),
                    const SizedBox(height: 10),
                    _buildPointSelectButton(
                      letter: 'B',
                      icon: Icons.flag,
                      color: Palette.pointB,
                      idleColor:
                          Palette.pointBFor(Theme.of(context).brightness),
                      tooltip: 'B noktası seç (haritaya dokun)',
                      isActive: _viewModel.selectionMode ==
                          MapPointSelectionMode.selectB,
                      onPressed: () => _startSelection(isStart: false),
                    ),
                  ],
                ),
              ),

              // --- 4. ALT KONTROL PANELLERİ (Durumsal Alt Sayfalar) ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: KeyedSubtree(
                  key: _bottomPanelKey,
                  child: _buildBottomPanel(context, currentPos, userLatLng),
                ),
              ),

              // --- 5. İZİN YOKSA BİLGİLENDİRME OVERLAY'İ ---
              // Konum hiç desteklenmiyorsa (Linux/Windows masaüstü) overlay
              // gösterilmez; "Yeniden Dene" bu durumda işe yaramaz.
              if (!_viewModel.isInitializing &&
                  !_viewModel.isPermissionGranted &&
                  !_viewModel.isLocationUnavailable)
                _buildPermissionOverlay(context),

              // --- 6. BAŞLANGIÇ YÜKLEME OVERLAY'İ ---
              if (_viewModel.isInitializing)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Harita ve konum başlatılıyor...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// GPS durum kartındaki ikon rengi (hata / iyi / zayıf).
  /// Hata ve zayıf doğruluk uyarı vurgusunu, iyi doğruluk birincili kullanır.
  Color _gpsStatusColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_viewModel.isGpsAccuracyGood) {
      return Palette.primaryFor(brightness);
    }
    return Palette.accentWarningFor(brightness);
  }

  /// İzin reddedildiğinde harita üzerinde gösterilen bilgilendirme paneli
  Widget _buildPermissionOverlay(BuildContext context) {
    // Koyu turuncu zemin + beyaz metin: WCAG AA kontrastını geçer.
    const overlayColor = Palette.accentWarning; // deepOrange.shade900
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        decoration: const BoxDecoration(
          color: overlayColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -3)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.location_off, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _viewModel.permissionDeniedReason.isNotEmpty
                        ? _viewModel.permissionDeniedReason
                        : 'Konum izni gerekli. Harita özellikleri devre dışı.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white60),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      // İzni yeniden iste
                      final result = await _viewModel.retryPermission();
                      if (!result && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_viewModel.permissionDeniedReason),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Yeniden Dene'),
                  ),
                ),
                if (_viewModel.isPermissionPermanentlyDenied) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: overlayColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        await Geolocator.openAppSettings();
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Ayarları Aç'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Uygulama yeniden açıldığında devam eden kayıt varsa kullanıcıya sor
  void _showResumeRecordingDialog() {
    if (!mounted) return;
    final active = _viewModel.activeBasket;
    if (active == null) return;

    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restore, color: Palette.primaryFor(scheme.brightness)),
            const SizedBox(width: 8),
            const Text('Devam Eden Kayıt'),
          ],
        ),
        content: Text(
          '"${active.name}" sepeti için A noktası daha önce kaydedilmişti.\n\n'
          'B noktasını şimdi kaydetmek ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _viewModel.cancelRecording();
            },
            child: Text('İptal Et', style: TextStyle(color: scheme.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  /// Alt panelin ölçülen yüksekliğine göre FAB konumunu döner.
  double _getBottomOffset() {
    return _bottomPanelHeight + 16;
  }

  /// Sol alttaki pusula/sensör-durum overlay'i.
  /// Sensör varsa canlı pusula kadranı, yoksa uyarı rozeti gösterir.
  Widget _buildCompassOverlay(BuildContext context) {
    final heading = _viewModel.currentHeading;
    if (heading != null) {
      return _buildCompassDial(context, heading);
    }
    if (_viewModel.isCompassUnavailable) {
      return _buildCompassUnavailableBadge();
    }
    return const SizedBox.shrink();
  }

  /// Sabit kadranlı (K/G/D/B) + dönen ibreli kompakt pusula.
  /// Sonsuz animasyon yok: Transform.rotate yalnızca heading değişince güncellenir.
  Widget _buildCompassDial(BuildContext context, double heading) {
    final headingRad = heading * math.pi / 180;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outline, width: 1.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Stack(
            children: [
              // Sabit kadran etiketleri: K üst, D sağ, G sol, B alt
              const Positioned(
                top: 3,
                left: 0,
                right: 0,
                child: Text(
                  'K',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const Positioned(
                bottom: 3,
                left: 0,
                right: 0,
                child: Text(
                  'B',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text('G',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text('D',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              // Dönen ibre: cihazın baktığı yönü gösterir
              Center(
                child: Transform.rotate(
                  angle: headingRad,
                  child: Icon(
                    Icons.navigation,
                    size: 34,
                    color: Palette.primaryFor(scheme.brightness),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Anlık yön harfi (K/D/G/B)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outline),
          ),
          child: Text(
            cardinalLabel(heading) ?? '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Palette.primaryFor(scheme.brightness),
            ),
          ),
        ),
      ],
    );
  }

  /// Sensör kullanılamadığında gösterilen uyarı rozeti (DESIGN.md: #BF360C).
  Widget _buildCompassUnavailableBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 150),
      decoration: BoxDecoration(
        color: Palette.accentWarning,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore_off, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Yön sensörü kullanılamıyor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hedef yön (A→B) ve gerekli dönüş açısı kartı.
  /// Hedef yön heading olmadan da gösterilir; dönüş yalnızca heading varken.
  Widget _buildBearingCard(BuildContext context) {
    final targetBearing = _viewModel.targetBearing;
    if (targetBearing == null) return const SizedBox.shrink();

    final rotation = _viewModel.requiredRotation;
    final scheme = Theme.of(context).colorScheme;
    final targetRad = targetBearing * math.pi / 180;

    final String rotationText;
    if (rotation == null) {
      rotationText = _viewModel.isCompassUnavailable ? 'Yön verisi yok' : '—';
    } else if (rotation >= 0) {
      rotationText = '+${rotation.toStringAsFixed(0)}° sağa';
    } else {
      rotationText = '${rotation.toStringAsFixed(0)}° sola';
    }

    final primaryColor = Palette.primaryFor(scheme.brightness);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor),
      ),
      child: Row(
        children: [
          // Hedef yön oku (A→B): kullanıcının yön okundan bağımsız, farklı renk
          Transform.rotate(
            angle: targetRad,
            child: Icon(
              Icons.navigation,
              size: 20,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hedef yön: ${targetBearing.toStringAsFixed(0)}°',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  'Dönüş: $rotationText',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  /// Harita dokunuşu: seçim modu aktifse dokunulan nokta A/B olur,
  /// ardından nokta adı sorulur. Mod yoksa hiçbir şey yapılmaz.
  void _onMapTap(LatLng point) {
    switch (_viewModel.selectionMode) {
      case MapPointSelectionMode.selectA:
        _promptPointName(
          isStart: true,
          initialName: _viewModel.activeBasket?.startName,
          onConfirm: (name) =>
              unawaited(_viewModel.setPointA(point, startName: name)),
        );
      case MapPointSelectionMode.selectB:
        _promptPointName(
          isStart: false,
          initialName: _viewModel.activeBasket?.endName,
          onConfirm: (name) =>
              unawaited(_viewModel.setPointB(point, endName: name)),
        );
      case MapPointSelectionMode.none:
        break;
    }
  }

  /// A/B seçim modunu başlatır. B için aktif (yarım) sepet gerekir.
  void _startSelection({required bool isStart}) {
    if (!isStart && _viewModel.activeBasket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('B noktası seçmek için önce A noktasını belirleyin.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (isStart) {
      _viewModel.startSelectingA();
    } else {
      _viewModel.startSelectingB();
    }
  }

  /// Nokta adı soran dialog. Boş bırakılırsa varsayılan ad ("A Noktası" /
  /// "B Noktası") kullanılır. İptal edilirse seçim modu kapatılır.
  void _promptPointName({
    required bool isStart,
    String? initialName,
    required ValueChanged<String> onConfirm,
  }) {
    final defaultName = isStart ? 'A Noktası' : 'B Noktası';
    final hasCustomName = initialName != null && initialName.trim().isNotEmpty;
    final controller =
        TextEditingController(text: hasCustomName ? initialName : defaultName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isStart ? 'A Noktası Adı' : 'B Noktası Adı'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: isStart ? 'A Noktası Adı' : 'B Noktası Adı',
            hintText: defaultName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim().isEmpty
                  ? defaultName
                  : controller.text.trim();
              Navigator.pop(dialogContext);
              onConfirm(name);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ).whenComplete(() {
      controller.dispose();
      // Onayda setPointA/B modu zaten kapatır; burada yalnızca iptal kapatır
      if (_viewModel.selectionMode != MapPointSelectionMode.none) {
        _viewModel.cancelSelection();
      }
    });
  }

  /// Harita üzerindeki marker altında gösterilen nokta adı etiketi.
  /// Beyaz zemin + koyu renk metin: her harita tonunda WCAG AA geçer.
  Widget _buildMarkerNameLabel(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(maxWidth: 96),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Harita kenarındaki A/B nokta seçim düğmesi (48px dokunma hedefi).
  /// Aktif modda dolu anlamsal renk + beyaz metin (rozet kalıbı), pasifte
  /// temaya uygun kenarlık/ikon rengi gösterir.
  Widget _buildPointSelectButton({
    required String letter,
    required IconData icon,
    required Color color,
    required Color idleColor,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final surface = Theme.of(context).colorScheme.surface;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? color : surface,
        shape: CircleBorder(
            side: BorderSide(color: isActive ? color : idleColor, width: 2)),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18, color: isActive ? Colors.white : idleColor),
                Text(
                  letter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : idleColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Seçim modu aktifken haritanın üstünde gösterilen yönerge bandı.
  Widget _buildSelectionBanner(BuildContext context) {
    final isSelectingA =
        _viewModel.selectionMode == MapPointSelectionMode.selectA;
    final color = isSelectingA ? Palette.pointA : Palette.pointB;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(isSelectingA ? Icons.location_on : Icons.flag,
              color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSelectingA
                  ? 'Haritaya dokunarak A noktasını belirle'
                  : 'Haritaya dokunarak B noktasını belirle',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _viewModel.cancelSelection,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 40),
            ),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  /// Alt paneldeki A/B nokta adı rozeti; dokununca isim düzenleme açılır.
  Widget _buildPointNameChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onEdit,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(
      BuildContext context, Position? currentPos, LatLng userLatLng) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = scheme.brightness;

    // 1. Durum: Aktif bir kayıt süreci var (A noktası alındı, B bekleniyor)
    if (_viewModel.activeBasket != null) {
      final active = _viewModel.activeBasket!;
      double distToStart = 0;
      if (currentPos != null) {
        distToStart =
            active.distanceToStart(currentPos.latitude, currentPos.longitude);
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _bottomPanelDecoration(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.radio_button_checked,
                    color: Palette.pointA),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${active.name} Kaydediliyor...',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // A noktası adı + düzenleme
            Row(
              children: [
                const Icon(Icons.location_on,
                    color: Palette.pointA, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'A: ${active.startDisplayName}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'A noktası adını düzenle',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _promptPointName(
                    isStart: true,
                    initialName: active.startName,
                    onConfirm: (name) => unawaited(
                      _viewModel.renamePointA(name, basketId: active.id),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'A Noktasına Uzaklığınız: ${distToStart.toStringAsFixed(1)} metre'),
            _buildBearingCard(context),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.pointBFor(brightness),
                  side: BorderSide(color: Palette.pointBFor(brightness)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _startSelection(isStart: false),
                icon: const Icon(Icons.flag),
                label: const Text('B Noktasını Haritadan Seç'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      _viewModel.cancelRecording();
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('İptal Et'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.pointB,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: !_viewModel.isGpsAccuracyGood
                        ? () => _showAccuracyWarning(
                            context, () => unawaited(_stopRecording(context)))
                        : () => unawaited(_stopRecording(context)),
                    icon: const Icon(Icons.stop),
                    label: const Text('B Noktası (Bitir)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 2. Durum: Katalogdan bir sepet seçilmiş (Detay Görünümü)
    if (_viewModel.selectedBasket != null) {
      final selected = _viewModel.selectedBasket!;
      double? distToStart;
      double? distToEnd;
      double? distToLine;
      if (currentPos != null) {
        distToStart = selected.distanceToStart(
            currentPos.latitude, currentPos.longitude);
        distToEnd =
            selected.distanceToEnd(currentPos.latitude, currentPos.longitude);
        distToLine =
            selected.distanceToLine(currentPos.latitude, currentPos.longitude);
      }

      final aColor = Palette.pointAFor(brightness);
      final bColor = Palette.pointBFor(brightness);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _bottomPanelDecoration(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.map, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Kapat',
                  onPressed: () => _viewModel.selectBasket(null),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // A/B nokta adları (dokununca düzenleme diyaloğu açılır)
            Row(
              children: [
                Expanded(
                  child: _buildPointNameChip(
                    label: selected.startDisplayName,
                    icon: Icons.location_on,
                    color: aColor,
                    onEdit: () => _promptPointName(
                      isStart: true,
                      initialName: selected.startName,
                      onConfirm: (name) => unawaited(
                        _viewModel.renamePointA(name, basketId: selected.id),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (selected.isCompleted)
                  Expanded(
                    child: _buildPointNameChip(
                      label: selected.endDisplayName,
                      icon: Icons.flag,
                      color: bColor,
                      onEdit: () => _promptPointName(
                        isStart: false,
                        initialName: selected.endName,
                        onConfirm: (name) => unawaited(
                          _viewModel.renamePointB(name, basketId: selected.id),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (selected.isCompleted) ...[
              Text(
                  'Sepet Uzunluğu: ${selected.distanceInMeters.toStringAsFixed(1)} metre'),
              if (distToLine != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Sepete Uzaklığınız: ${distToLine.toStringAsFixed(1)} m',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
              if (distToStart != null && distToEnd != null) ...[
                const SizedBox(height: 8),
                // Anlık mesafe kartları: her konum güncellemesinde otomatik yenilenir
                Row(
                  children: [
                    // A Noktasına Anlık Mesafe
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: aColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: aColor, size: 8),
                                const SizedBox(width: 4),
                                Text(
                                  selected.startDisplayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: aColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${distToStart.toStringAsFixed(1)} m',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // B Noktasına Anlık Mesafe
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: bColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: bColor, size: 8),
                                const SizedBox(width: 4),
                                Text(
                                  selected.endDisplayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: bColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${distToEnd.toStringAsFixed(1)} m',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ] else
              const Text('Sepet tamamlanmamış durumda (B noktası eksik).'),
            _buildBearingCard(context),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      _viewModel.selectBasket(null);
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Seçimi Kaldır'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      ShareService().shareBasket(
                        selected,
                        targetPhoneNumber:
                            _settingsService.settings.backupPhoneNumber,
                        currentHeading: _viewModel.currentHeading,
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('WhatsApp Paylaş'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 3. Durum: Varsayılan Durum (Kayıt yok, seçim yok -> Yeni Sepet Başlatma)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _bottomPanelDecoration(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sepet için A noktasını haritadan seçin (sağdaki A düğmesi) veya GPS konumunuzla kaydı başlatın.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          _buildBearingCard(context),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.pointA,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: !_viewModel.isGpsAccuracyGood
                  ? () => _showAccuracyWarning(
                      context, () => _startRecordingDialog(context))
                  : () => _startRecordingDialog(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                'Sepet Başlat (A Noktası)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _bottomPanelDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 10,
          spreadRadius: 2,
          offset: const Offset(0, -3),
        )
      ],
    );
  }

  void _showAccuracyWarning(BuildContext context, VoidCallback onProceed) {
    final warningColor =
        Palette.accentWarningFor(Theme.of(context).brightness);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: warningColor),
            const SizedBox(width: 8),
            const Text('Düşük Sinyal Uyarısı'),
          ],
        ),
        content: Text(
          'GPS hassasiyeti şu anda zayıf (Doğruluk toleransı > ${_settingsService.settings.gpsAccuracyThreshold.toStringAsFixed(0)}m).\n\n'
          'Kaydedeceğiniz konum sapmalı olabilir. Yine de devam etmek istiyor musunuz?\n\n'
          'İpucu: Açık alana çıkın veya GPS Boost modunu aktifleştirin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekle / İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Palette.accentWarning,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              onProceed();
            },
            child: const Text('Yine de Devam Et'),
          ),
        ],
      ),
    );
  }

  void _startRecordingDialog(BuildContext context) {
    final defaultName = 'Sepet #${_viewModel.baskets.length + 1}';
    final nameController = TextEditingController(text: defaultName);
    final startNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Sepet Başlat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Sepet Adı / Numarası',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: startNameController,
              decoration: const InputDecoration(
                labelText: 'A Noktası Adı',
                hintText: 'A Noktası',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim().isEmpty
                  ? defaultName
                  : nameController.text.trim();
              final startName = startNameController.text.trim().isEmpty
                  ? null
                  : startNameController.text.trim();

              Navigator.pop(context);
              final success = await _viewModel
                  .startRecordingBasket(name, startName: startName);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          '$name başlangıç (A) noktası kaydedildi.')),
                );
              }
            },
            child: const Text('Başlat'),
          ),
        ],
      ),
      // Dialog kapandığında (İptal / Başlat / dışarı tık) controller'ları serbest bırak
    ).whenComplete(() {
      nameController.dispose();
      startNameController.dispose();
    });
  }

  Future<void> _stopRecording(BuildContext context) async {
    // B noktası adını sor; boş bırakılırsa varsayılan ("B Noktası") kullanılır
    final endNameController = TextEditingController();
    final endName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('B Noktası Adı'),
        content: TextField(
          controller: endNameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'B Noktası Adı',
            hintText: 'B Noktası',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              endNameController.text.trim().isEmpty
                  ? 'B Noktası'
                  : endNameController.text.trim(),
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ).whenComplete(endNameController.dispose);

    if (endName == null || !context.mounted) return; // İptal edildi

    final completed =
        await _viewModel.stopRecordingBasket(endName: endName);
    if (completed != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${completed.name} bitiş (B) noktası kaydedildi.')),
      );

      // Otomatik paylaşım teklifi / yönlendirmesi
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sepet Tamamlandı'),
          content: Text(
              '${completed.name} başarıyla kaydedildi.\n\nKonum bilgilerini şimdi WhatsApp grubuna göndermek ister misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Daha Sonra'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ShareService().shareBasket(
                  completed,
                  targetPhoneNumber:
                      _settingsService.settings.backupPhoneNumber,
                  currentHeading: _viewModel.currentHeading,
                );
              },
              child: const Text('WhatsApp Paylaş'),
            ),
          ],
        ),
      );
    }
  }
}
