import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'sqlite_tile_cache_service.dart';

/// flutter_map için SQLite destekli TileProvider.
///
/// Davranış:
///   1. SQLite önbelleğinde tile varsa → doğrudan MemoryImage döner (offline çalışır)
///   2. Önbellekte yoksa → OSM'den indirir, SQLite'a kaydeder, MemoryImage döner
///   3. Her ikisi de başarısızsa → şeffaf boş tile döner (uygulama çökmez)
class SqliteTileProvider extends TileProvider {
  final _cache = SqliteTileCacheService();
  final HttpClient _httpClient = HttpClient();

  SqliteTileProvider() {
    _httpClient.connectionTimeout = const Duration(seconds: 12);
  }

  @override
  void dispose() {
    _httpClient.close(force: false);
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
    );
  }
}

// ---------------------------------------------------------------------------
// Dahili ImageProvider — SQLite cache + network fallback
// ---------------------------------------------------------------------------

class _SqliteTileImageProvider
    extends ImageProvider<_SqliteTileImageProvider> {
  final TileCoordinates coordinates;
  final TileLayer options;
  final SqliteTileCacheService cache;
  final HttpClient httpClient;
  final String Function(TileCoordinates, TileLayer) tileUrlBuilder;
  final Map<String, String> tileHeaders;

  const _SqliteTileImageProvider({
    required this.coordinates,
    required this.options,
    required this.cache,
    required this.httpClient,
    required this.tileUrlBuilder,
    required this.tileHeaders,
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

    // 1. Önbellekten dene
    final cached = await cache.getTile(z, x, y);
    if (cached != null) {
      return _decodeBytes(cached, decode);
    }

    // 2. Ağdan indir
    final url = tileUrlBuilder(coordinates, options);
    try {
      final request = await httpClient.getUrl(Uri.parse(url));
      tileHeaders.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response
            .fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
        final data = Uint8List.fromList(bytes);
        // Arka planda kaydet (awaitsiz — UI'yı bloklamaz)
        cache.saveTile(z, x, y, data);
        return _decodeBytes(data, decode);
      }
    } catch (_) {
      // Ağ hatası — boş tile döner
    }

    // 3. Fallback: 1×1 şeffaf PNG
    return _decodeBytes(_kTransparentPng, decode);
  }

  Future<ImageInfo> _decodeBytes(
      Uint8List bytes, ImageDecoderCallback decode) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      other is _SqliteTileImageProvider &&
      coordinates == other.coordinates &&
      options.urlTemplate == other.options.urlTemplate;

  @override
  int get hashCode => Object.hash(coordinates, options.urlTemplate);
}

// 1×1 şeffaf PNG (fallback tile)
final Uint8List _kTransparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);
