import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/services/settings_service.dart';
import 'package:map/services/share_service.dart';
import 'package:map/services/tile_cache_service.dart';
import 'package:map/viewmodels/map_viewmodel.dart';
import 'package:map/views/ayarlar_ekran.dart';
import 'package:map/views/katalog_sayfasi.dart';

class HaritaEkran extends StatefulWidget {
  const HaritaEkran({super.key});

  @override
  State<HaritaEkran> createState() => _HaritaEkranState();
}

class _HaritaEkranState extends State<HaritaEkran> {
  final MapViewModel _viewModel = MapViewModel();
  final MapController _mapController = MapController();
  final _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _viewModel.init();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Haritayı belirli bir konuma odaklar
  void _focusOnLocation(LatLng point, double zoom) {
    _mapController.move(point, zoom);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final currentPos = _viewModel.currentPosition;
        final userLatLng = currentPos != null 
            ? LatLng(currentPos.latitude, currentPos.longitude) 
            : const LatLng(38.25, 30.90); // Eğirdir Gölü varsayılan merkez

        // Haritada gösterilecek aktif veya seçili sepet
        final showBasket = _viewModel.selectedBasket ?? _viewModel.activeBasket;

        return Scaffold(
          body: Stack(
            children: [
              // --- 1. HARİTA KATMANI (Tile, Polyline, Circle, Marker) ---
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: userLatLng,
                  initialZoom: 12.0,
                  maxZoom: 18.0,
                  minZoom: 6.0,
                ),
                children: [
                  // Harita Altlığı (Tile Layer) - Çevrimdışı Önbellek Desteği ile
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rumata.gol_sepet_takip',
                    tileProvider: _settingsService.settings.enableTileCaching &&
                            TileCacheService().cacheDirectory != null
                        ? CachedTileProvider(cacheDir: TileCacheService().cacheDirectory!)
                        : NetworkTileProvider(),
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
                              ? Colors.blue.withOpacity(0.15)
                              : Colors.red.withOpacity(0.15),
                          borderColor: _viewModel.isGpsAccuracyGood
                              ? Colors.blue.withOpacity(0.5)
                              : Colors.red.withOpacity(0.5),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),

                  // Sepet Çizgisi (A -> B Arasındaki Çizgi)
                  if (showBasket != null && showBasket.endLatitude != null && showBasket.endLongitude != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            LatLng(showBasket.startLatitude, showBasket.startLongitude),
                            LatLng(showBasket.endLatitude!, showBasket.endLongitude!),
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
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
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

                      // Sepet Başlangıç (A) Noktası
                      if (showBasket != null)
                        Marker(
                          point: LatLng(showBasket.startLatitude, showBasket.startLongitude),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),

                      // Sepet Bitiş (B) Noktası
                      if (showBasket != null && showBasket.endLatitude != null && showBasket.endLongitude != null)
                        Marker(
                          point: LatLng(showBasket.endLatitude!, showBasket.endLongitude!),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.flag,
                            color: Colors.red,
                            size: 40,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.gps_fixed,
                                color: _viewModel.isGpsAccuracyGood ? Colors.green : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _viewModel.gpsStatusText,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                      color: _viewModel.isBoostMode ? Colors.amber.shade700 : Colors.grey.shade700,
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
                              backupPhoneNumber: _settingsService.settings.backupPhoneNumber,
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
                            builder: (context) => AyarlarEkran(viewModel: _viewModel),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // --- 3. HARİTA KONTROL ARAÇLARI (Konumuma Git) ---
              Positioned(
                bottom: _getBottomOffset(showBasket),
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade700,
                  onPressed: () {
                    if (currentPos != null) {
                      _focusOnLocation(userLatLng, 15.0);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Konumunuz henüz alınamadı.')),
                      );
                    }
                  },
                  child: const Icon(Icons.my_location),
                ),
              ),

              // --- 4. ALT KONTROL PANELERİ (Durumsal Alt Sayfalar) ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomPanel(context, currentPos, userLatLng),
              ),
            ],
          ),
        );
      },
    );
  }

  double _getBottomOffset(BasketModel? showBasket) {
    if (showBasket == null) return 100.0;
    return 210.0;
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
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, Position? currentPos, LatLng userLatLng) {
    // 1. Durum: Aktif bir kayıt süreci var (A noktası alındı, B bekleniyor)
    if (_viewModel.activeBasket != null) {
      final active = _viewModel.activeBasket!;
      double distToStart = 0;
      if (currentPos != null) {
        distToStart = active.distanceToStart(currentPos.latitude, currentPos.longitude);
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _bottomPanelDecoration(),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('A Noktasına Uzaklığınız: ${distToStart.toStringAsFixed(1)} metre'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
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
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: !_viewModel.isGpsAccuracyGood
                        ? () => _showAccuracyWarning(context, () => _stopRecording(context))
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
      if (currentPos != null) {
        distToStart = selected.distanceToStart(currentPos.latitude, currentPos.longitude);
        distToEnd = selected.distanceToEnd(currentPos.latitude, currentPos.longitude);
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _bottomPanelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _viewModel.selectBasket(null),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (selected.isCompleted) ...[
              Text('Sepet Uzunluğu: ${selected.distanceInMeters.toStringAsFixed(1)} metre'),
              if (distToStart != null && distToEnd != null) ...[
                const SizedBox(height: 2),
                Text('A Noktasına Uzaklığınız: ${distToStart.toStringAsFixed(1)} m'),
                Text('B Noktasına Uzaklığınız: ${distToEnd.toStringAsFixed(1)} m'),
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
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      ShareService().shareBasket(
                        selected,
                        targetPhoneNumber: _settingsService.settings.backupPhoneNumber,
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
      decoration: _bottomPanelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sepet konum takibi yapmak için A noktasında kaydı başlatın.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: !_viewModel.isGpsAccuracyGood
                  ? () => _showAccuracyWarning(context, () => _startRecordingDialog(context))
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

  BoxDecoration _bottomPanelDecoration() {
    return const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 10,
          spreadRadius: 2,
          offset: Offset(0, -3),
        )
      ],
    );
  }

  void _showAccuracyWarning(BuildContext context, VoidCallback onProceed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade800),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () {
              Navigator.pop(context);
              onProceed();
            },
            child: const Text('Yine de Devam Et', style: TextStyle(color: Colors.white)),
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
              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$name başlangıç (A) noktası kaydedildi.')),
                  );
                }
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
    if (completed != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${completed.name} bitiş (B) noktası kaydedildi.')),
      );

      // Otomatik paylaşım teklifi / yönlendirmesi
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sepet Tamamlandı'),
          content: Text('${completed.name} başarıyla kaydedildi.\n\nKonum bilgilerini şimdi WhatsApp grubuna göndermek ister misiniz?'),
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
                  targetPhoneNumber: _settingsService.settings.backupPhoneNumber,
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
