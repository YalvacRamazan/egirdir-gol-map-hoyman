import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/services/settings_service.dart';
import 'package:map/services/share_service.dart';
import 'package:map/services/sqlite_tile_provider.dart';
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
    super.dispose();
  }

  /// Haritayı belirli bir konuma odaklar
  void _focusOnLocation(LatLng point, double zoom) {
    _mapController.move(point, zoom);
  }

  /// Açık/koyu temaya göre uygun rengi seçer.
  Color _adaptiveColor(BuildContext context, Color light, Color dark) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
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
        WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomPanel());

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
                ),
                children: [
                  // Harita Altlığı (Tile Layer) - SQLite Önbellek Desteği ile
                  // Görüntülenen tile'lar otomatik indirilip SQLite'a kaydedilir.
                  // Bir sonraki açılışta (offline dahil) doğrudan SQLite'tan okunur.
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rumata.gol_sepet_takip',
                    tileProvider: SqliteTileProvider(),
                  ),

                  // GPS Doğruluk Çemberi (Sadece GPS aktifse çizilir)
                  if (currentPos != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: userLatLng,
                          radius: currentPos.accuracy, // Metre cinsinden doğruluk yarıçapı
                          useRadiusInMeter: true,
                          color: _viewModel.isGpsAccuracyGood
                              ? Colors.blue.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          borderColor: _viewModel.isGpsAccuracyGood
                              ? Colors.blue.withValues(alpha: 0.5)
                              : Colors.red.withValues(alpha: 0.5),
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
                          color: Colors.blue.shade900,
                        ),
                      ],
                    ),

                  // İşaretçiler (User, A Noktası, B Noktası)
                  MarkerLayer(
                    markers: [
                      // Kullanıcı Konumu İşaretçisi
                      if (currentPos != null)
                        Marker(
                          point: userLatLng,
                          width: 20,
                          height: 20,
                          child: Semantics(
                            label: 'Kullanıcı konumu',
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Sepet Başlangıç (A) Noktası
                      if (showBasket != null)
                        Marker(
                          point: LatLng(showBasket.startLatitude,
                              showBasket.startLongitude),
                          width: 40,
                          height: 40,
                          child: Semantics(
                            label: 'Sepet başlangıç noktası (A)',
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.green,
                              size: 40,
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
                          width: 40,
                          height: 40,
                          child: Semantics(
                            label: 'Sepet bitiş noktası (B)',
                            child: const Icon(
                              Icons.flag,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
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
                                      fontSize: 12,
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
                          ? Colors.deepOrange.shade900
                          : Colors.grey.shade700,
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
                      color: Colors.blue.shade700,
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
                      color: Colors.grey.shade800,
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
              if (!_viewModel.isInitializing && !_viewModel.isPermissionGranted)
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
  Color _gpsStatusColor(BuildContext context) {
    if (_viewModel.isGpsError) {
      return Theme.of(context).colorScheme.error;
    }
    if (_viewModel.isGpsAccuracyGood) {
      return _adaptiveColor(context, Colors.green.shade700, Colors.green.shade300);
    }
    return _adaptiveColor(context, Colors.orange.shade800, Colors.orange.shade300);
  }

  /// İzin reddedildiğinde harita üzerinde gösterilen bilgilendirme paneli
  Widget _buildPermissionOverlay(BuildContext context) {
    // Koyu turuncu zemin + beyaz metin: WCAG AA kontrastını geçer.
    const overlayColor = Color(0xFFBF360C); // deepOrange.shade900
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
            Icon(Icons.restore, color: Colors.green.shade800),
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
              backgroundColor: Colors.green.shade800,
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

  Widget _buildBottomPanel(
      BuildContext context, Position? currentPos, LatLng userLatLng) {
    final scheme = Theme.of(context).colorScheme;

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
                const Icon(Icons.radio_button_checked, color: Colors.green),
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
            const SizedBox(height: 8),
            Text(
                'A Noktasına Uzaklığınız: ${distToStart.toStringAsFixed(1)} metre'),
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
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: !_viewModel.isGpsAccuracyGood
                        ? () => _showAccuracyWarning(
                            context, () => _stopRecording(context))
                        : () => _stopRecording(context),
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

      final aColor = _adaptiveColor(context, Colors.green.shade800, Colors.green.shade300);
      final bColor = _adaptiveColor(context, Colors.red.shade800, Colors.red.shade300);

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
                                  'A Noktası',
                                  style: TextStyle(
                                    fontSize: 11,
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
                                  'B Noktası',
                                  style: TextStyle(
                                    fontSize: 11,
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
                      backgroundColor: Colors.green.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      ShareService().shareBasket(
                        selected,
                        targetPhoneNumber:
                            _settingsService.settings.backupPhoneNumber,
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
            'Sepet konum takibi yapmak için A noktasında kaydı başlatın.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
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
        _adaptiveColor(context, Colors.deepOrange.shade900, Colors.orange.shade300);
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
                backgroundColor: Colors.deepOrange.shade900,
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Sepet Başlat'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Sepet Adı / Numarası',
            border: OutlineInputBorder(),
          ),
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

              Navigator.pop(context);
              final success = await _viewModel.startRecordingBasket(name);
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
    );
  }

  void _stopRecording(BuildContext context) async {
    final completed = await _viewModel.stopRecordingBasket();
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
