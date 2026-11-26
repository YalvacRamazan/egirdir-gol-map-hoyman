import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'hoyman_tile_region.dart';
import 'sqlite_tile_cache_service.dart';

/// Tile istekleri ağ hatasıyla sonuçlandığında offline moda geçer; offline
/// modda yalnızca önbellek kullanılır ve periyodik probe ile bağlantının
/// dönüp dönmediği kontrol edilir. Bağlantı dönünce onBackOnline çağrılır.
class SqliteTileProvider extends TileProvider {
  final _cache = SqliteTileCacheService();
  final HttpClient _httpClient = HttpClient();

  final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  /// Offline'dan online'a geçişte tetiklenir; harita görünür tile'ları
  /// yeniden istemek için bunu kullanır.
  final void Function()? onBackOnline;

  /// Offline moddayken bağlantıyı denemek için aralık.
  static const Duration probeInterval = Duration(seconds: 20);

  Timer? _probeTimer;
  bool _probing = false;

  SqliteTileProvider({this.onBackOnline}) {
    _httpClient.connectionTimeout = const Duration(seconds: 12);
    _httpClient.idleTimeout = const Duration(seconds: 30);
    _httpClient.maxConnectionsPerHost = 4;
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    _httpClient.close(force: false);
    offline.dispose();
    super.dispose();
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _SqliteTileImageProvider(
      coordinates: coordinates,
      options: options,
      cache: _cache,
      httpClient: _httpClient,
      tileUrlBuilder: (c, o) => getTileUrl(c, o),
      tileHeaders: headers,
      offline: offline,
      onNetworkError: _enterOfflineMode,
    );
  }

  void _enterOfflineMode() {
    if (!offline.value) {
      offline.value = true;
    }
    _scheduleProbe();
  }

  void _scheduleProbe() {
    if (_probeTimer != null) return;
    _probeTimer = Timer(probeInterval, () {
      _probeTimer = null;
      _runProbe();
    });
  }

  /// Offline moddayken bağlantıyı yoklar; başarılıysa online moda döner.
  Future<void> _runProbe() async {
    if (!offline.value || _probing) return;
    _probing = true;
    try {
      final request = await _httpClient
          .getUrl(Uri.parse('https://tile.openstreetmap.org/0/0/0.png'))
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(const Duration(seconds: 8));
      await response.drain<void>();
      if (response.statusCode == 200 && offline.value) {
        offline.value = false;
        onBackOnline?.call();
      }
    } catch (_) {
      // Bağlantı hâlâ yok; sonraki probe denemesini planla.
    } finally {
      _probing = false;
      if (offline.value) _scheduleProbe();
    }
  }
}

class _SqliteTileImageProvider
    extends ImageProvider<_SqliteTileImageProvider> {
  final TileCoordinates coordinates;
  final TileLayer options;
  final SqliteTileCacheService cache;
  final HttpClient httpClient;
  final String Function(TileCoordinates, TileLayer) tileUrlBuilder;
  final Map<String, String> tileHeaders;
  final ValueNotifier<bool> offline;
  final void Function()? onNetworkError;

  const _SqliteTileImageProvider({
    required this.coordinates,
    required this.options,
    required this.cache,
    required this.httpClient,
    required this.tileUrlBuilder,
    required this.tileHeaders,
    required this.offline,
    this.onNetworkError,
  });

  @override
  Future<_SqliteTileImageProvider> obtainKey(
          ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      _SqliteTileImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(
      _fetchTile(key, decode),
      informationCollector: () => [
        DiagnosticsProperty('coordinates', coordinates),
      ],
    );
  }

  Future<ImageInfo> _fetchTile(
      _SqliteTileImageProvider key, ImageDecoderCallback decode) async {
    final z = coordinates.z.toInt();
    final x = coordinates.x;
    final y = coordinates.y;

    final cached = await cache.getTile(z, x, y);
    if (cached != null) {
      return _decodeBytes(cached, decode);
    }

    // Offline modda ağ isteği yapılmaz; tile yoksa hata fırlatılır.
    // Hata, ImageCache'e boş görsel yazılmasını engeller ve tile daha sonra
    // tekrar denenebilir kalır.
    if (offline.value) {
      throw StateError('Tile offline modda önbellekte yok: $z/$x/$y');
    }

    final url = tileUrlBuilder(coordinates, options);
    final uri = Uri.tryParse(url);
    // Yalnızca https tile URL'leri kabul edilir (yanlış yapılandırmaya karşı savunma).
    if (uri == null || uri.scheme != 'https') {
      if (kDebugMode) {
        debugPrint('SqliteTileProvider: geçersiz tile URL reddedildi: $url');
      }
      throw StateError('Geçersiz tile URL: $url');
    }
    try {
      final request = await httpClient.getUrl(uri);
      tileHeaders.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close();
      if (response.statusCode == 200) {
        _goOnline();
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response) {
          builder.add(chunk);
        }
        final data = builder.takeBytes();
        unawaited(cache.saveTile(
          z,
          x,
          y,
          data,
          permanent: HoymanTileRegion.containsTile(z, x, y),
        ));
        return await _decodeBytes(data, decode);
      }
      _reportNetworkError();
    } catch (_) {
      _reportNetworkError();
    }

    throw StateError('Tile yüklenemedi: $z/$x/$y');
  }

  void _goOnline() {
    if (offline.value) offline.value = false;
  }

  void _reportNetworkError() {
    onNetworkError?.call();
  }

  Future<ImageInfo> _decodeBytes(
      Uint8List bytes, ImageDecoderCallback decode) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.Codec? codec;
    try {
      codec = await decode(buffer);
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image);
    } finally {
      codec?.dispose();
      buffer.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _SqliteTileImageProvider &&
      coordinates == other.coordinates &&
      options.urlTemplate == other.options.urlTemplate;

  @override
  int get hashCode => Object.hash(coordinates, options.urlTemplate);
}
