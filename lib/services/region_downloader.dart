import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'hoyman_tile_region.dart';
import 'sqlite_tile_cache_service.dart';

class RegionDownloadProgress {
  final int total;

  final int done;

  final int failed;

  final bool running;

  const RegionDownloadProgress({
    required this.total,
    required this.done,
    required this.failed,
    required this.running,
  });
}

/// Hoyman Gölü bölgesinin tüm tile'larını kalıcı önbelleğe indirir.
/// Uygulama ömrü boyunca tek örnek olarak yaşar.
class RegionDownloader {
  static final RegionDownloader _instance = RegionDownloader._internal();
  factory RegionDownloader() => _instance;
  RegionDownloader._internal() {
    _httpClient.connectionTimeout = const Duration(seconds: 12);
    _httpClient.idleTimeout = const Duration(seconds: 30);
    _httpClient.maxConnectionsPerHost = 4;
  }

  static const String _tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _userAgent = 'com.rumata.gol_sepet_takip';

  final HttpClient _httpClient = HttpClient();

  final ValueNotifier<RegionDownloadProgress?> progress =
      ValueNotifier<RegionDownloadProgress?>(null);

  bool _cancelRequested = false;

  void cancel() => _cancelRequested = true;

  void dispose() {
    _httpClient.close(force: false);
  }

  Future<void> downloadRegion(SqliteTileCacheService cache) async {
    if (progress.value?.running == true) return;
    _cancelRequested = false;
    progress.value = const RegionDownloadProgress(
      total: 0,
      done: 0,
      failed: 0,
      running: true,
    );

    // 1. Bölgenin tüm (z, x, y) listesini üret.
    final allTiles = HoymanTileRegion.allTiles();

    // 2. Zaten önbellekte olanları atla.
    final pending = <(int, int, int)>[];
    for (final tile in allTiles) {
      if (_cancelRequested) break;
      final (z, x, y) = tile;
      if (await cache.hasTile(z, x, y)) continue;
      pending.add(tile);
    }

    final total = pending.length;
    var done = 0;
    var failed = 0;

    void updateProgress() {
      progress.value = RegionDownloadProgress(
        total: total,
        done: done,
        failed: failed,
        running: true,
      );
    }

    updateProgress();

    // 3. Eşzamanlılık 2: iki worker sıradaki tile'ı çeker.
    var nextIndex = 0;
    Future<void> worker() async {
      while (!_cancelRequested && nextIndex < total) {
        final tile = pending[nextIndex++];
        final (z, x, y) = tile;
        final ok = await _downloadTile(z, x, y, cache);
        if (ok) {
          done++;
        } else {
          failed++;
        }
        updateProgress();
      }
    }

    await Future.wait([worker(), worker()]);

    // 4. Son durumu bildir.
    progress.value = RegionDownloadProgress(
      total: total,
      done: done,
      failed: failed,
      running: false,
    );
  }

  Future<bool> _downloadTile(
    int z,
    int x,
    int y,
    SqliteTileCacheService cache,
  ) async {
    if (_cancelRequested) return false;
    try {
      final url = _tileUrlTemplate
          .replaceFirst('{z}', z.toString())
          .replaceFirst('{x}', x.toString())
          .replaceFirst('{y}', y.toString());
      final request = await _httpClient.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close();
      if (response.statusCode != 200) {
        // 429/5xx ve diğer durum kodları hata sayılır.
        return false;
      }

      // Akış sırasında iptal gelirse soketi kes; veri diske yazılmaz.
      final builder = BytesBuilder(copy: false);
      var cancelled = false;
      await for (final chunk in response) {
        if (_cancelRequested) {
          cancelled = true;
          break;
        }
        builder.add(chunk);
      }
      if (cancelled) {
        await _detachAndDestroy(response);
        return false;
      }

      await cache.saveTile(
        z,
        x,
        y,
        builder.takeBytes(),
        permanent: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Yanıtın tuttuğu soketi serbest bırakır; iptal edilen indirmelerin
  /// bağlantı havuzunda askıda kalmamasını sağlar.
  Future<void> _detachAndDestroy(HttpClientResponse response) async {
    try {
      final socket = await response.detachSocket();
      socket.destroy();
    } catch (_) {
      // Soket zaten kapalı olabilir.
    }
  }
}
