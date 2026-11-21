import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/services/settings_service.dart';
import 'package:map/services/share_service.dart';
import 'package:map/theme/palette.dart';
import 'package:map/utils/bearing.dart';
import 'package:map/utils/time_format.dart';
import 'package:map/viewmodels/map_viewmodel.dart';
import 'package:map/views/ayarlar_ekran.dart';
import 'package:map/views/katalog_sayfasi.dart';
import 'package:map/widgets/distance_gauge.dart';
import 'package:map/widgets/status_widgets.dart';

const LatLng _kHoymanGoluMerkezi = LatLng(38.10, 30.98);

const double _kFallbackSpeedMps = 2.0;

class HaritaEkran extends StatefulWidget {
  const HaritaEkran({super.key});

  @override
  State<HaritaEkran> createState() => _HaritaEkranState();
}

class _HaritaEkranState extends State<HaritaEkran> {
  final MapViewModel _viewModel = MapViewModel();
  final MapController _mapController = MapController();
  final _settingsService = SettingsService();

  final TileProvider _tileProvider = NetworkTileProvider();

  bool _isMeasureScheduled = false;

  final GlobalKey _bottomPanelKey = GlobalKey();
  double _bottomPanelHeight = 0;

  bool _hasMovedToPosition = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.init().then((_) {
      if (mounted && _viewModel.activeBasket != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showResumeRecordingDialog();
        });
      }
    });
  }

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

  void _focusOnLocation(LatLng point, double zoom) {
    _mapController.move(point, zoom);
  }

  void _measureBottomPanel() {
    final ctx = _bottomPanelKey.currentContext;
    if (ctx == null) return;
    final h = ctx.size?.height ?? 0;
    if (h != _bottomPanelHeight && mounted) {
      setState(() => _bottomPanelHeight = h);
    }
  }

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

        final showBasket = _viewModel.selectedBasket ?? _viewModel.activeBasket;

        final basketDistance = showBasket != null
            ? _distanceToBasket(showBasket, currentPos)
            : null;
        final estimatedArrival = _estimateArrival(basketDistance, currentPos);

        _scheduleBottomPanelMeasure();

        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _kHoymanGoluMerkezi,
                  initialZoom: 12.0,
                  maxZoom: 18.0,
                  minZoom: 6.0,
                  onTap: (tapPosition, point) => _onMapTap(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rumata.gol_sepet_takip',
                    tileProvider: _tileProvider,
                  ),

                  if (currentPos != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: userLatLng,
                          radius: currentPos.accuracy,
                          useRadiusInMeter: true,
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

                  MarkerLayer(
                    markers: [
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

                      if (showBasket != null)
                        Marker(
                          point: LatLng(showBasket.startLatitude,
                              showBasket.startLongitude),
                          width: 100,
                          height: 64,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
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

              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 12,
                right: 12,
                child: Row(
                  children: [
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

              Positioned(
                top: MediaQuery.of(context).padding.top + 62,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 36,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const LiveClockChip(),
                        if (estimatedArrival != null) ...[
                          const SizedBox(width: 8),
                          StatusPill(
                            icon: Icons.schedule,
                            text:
                                'Varış ~${formatHourMinute(estimatedArrival)}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              if (_viewModel.selectionMode != MapPointSelectionMode.none)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 104,
                  left: 12,
                  right: 12,
                  child: _buildSelectionBanner(context),
                ),

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

              Positioned(
                bottom: _getBottomOffset(),
                left: 16,
                child: _buildCompassOverlay(context),
              ),

              if (basketDistance != null &&
                  _viewModel.selectionMode == MapPointSelectionMode.none)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 112,
                  left: 12,
                  child: DistanceGauge(distanceMeters: basketDistance),
                ),

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

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: KeyedSubtree(
                  key: _bottomPanelKey,
                  child: _buildBottomPanel(context, currentPos, userLatLng),
                ),
              ),

              if (!_viewModel.isInitializing &&
                  !_viewModel.isPermissionGranted &&
                  !_viewModel.isLocationUnavailable)
                _buildPermissionOverlay(context),

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

  double? _distanceToBasket(BasketModel basket, Position? pos) {
    if (pos == null) return null;
    if (basket.isCompleted &&
        basket.endLatitude != null &&
        basket.endLongitude != null) {
      return basket.distanceToLine(pos.latitude, pos.longitude);
    }
    return basket.distanceToStart(pos.latitude, pos.longitude);
  }

  DateTime? _estimateArrival(double? distanceMeters, Position? pos) {
    if (distanceMeters == null) return null;
    final speed = pos?.speed ?? 0;
    final effectiveSpeed =
        (speed.isFinite && speed > 0.5) ? speed : _kFallbackSpeedMps;
    final seconds = (distanceMeters / effectiveSpeed).round();
    return DateTime.now().add(Duration(seconds: seconds));
  }

  Color _gpsStatusColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_viewModel.isGpsAccuracyGood) {
      return Palette.primaryFor(brightness);
    }
    return Palette.accentWarningFor(brightness);
  }

  Widget _buildPermissionOverlay(BuildContext context) {
    const overlayColor = Palette.accentWarning;
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

  double _getBottomOffset() {
    return _bottomPanelHeight + 16;
  }

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
      if (_viewModel.selectionMode != MapPointSelectionMode.none) {
        _viewModel.cancelSelection();
      }
    });
  }

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
                Row(
                  children: [
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
    ).whenComplete(() {
      nameController.dispose();
      startNameController.dispose();
    });
  }

  Future<void> _stopRecording(BuildContext context) async {
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

    if (endName == null || !context.mounted) return;

    final completed =
        await _viewModel.stopRecordingBasket(endName: endName);
    if (completed != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${completed.name} bitiş (B) noktası kaydedildi.')),
      );

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
