import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'hoyman_tile_region.dart';
import 'sqlite_tile_cache_service.dart';

class SqliteTileProvider extends TileProvider {
  final _cache = SqliteTileCacheService();
  final HttpClient _httpClient = HttpClient();

  final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  final void Function()? onNetworkError;

  SqliteTileProvider({this.onNetworkError}) {
    _httpClient.connectionTimeout = const Duration(seconds: 12);
    _httpClient.idleTimeout = const Duration(seconds: 30);
    _httpClient.maxConnectionsPerHost = 4;
  }

  @override
  void dispose() {
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
      onNetworkError: onNetworkError,
    );
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

    final url = tileUrlBuilder(coordinates, options);
    final uri = Uri.tryParse(url);
    // Yalnızca https tile URL'leri kabul edilir (yanlış yapılandırmaya karşı savunma).
    if (uri == null || uri.scheme != 'https') {
      if (kDebugMode) {
        debugPrint('SqliteTileProvider: geçersiz tile URL reddedildi: $url');
      }
      return _decodeBytes(_kTransparentPng, decode);
    }
    try {
      final request = await httpClient.getUrl(uri);
      tileHeaders.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close();
      if (response.statusCode == 200) {
        _reportOnline();
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

    return _decodeBytes(_kTransparentPng, decode);
  }

  void _reportOnline() {
    if (offline.value) offline.value = false;
  }

  void _reportNetworkError() {
    if (!offline.value) {
      offline.value = true;
      onNetworkError?.call();
    }
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
