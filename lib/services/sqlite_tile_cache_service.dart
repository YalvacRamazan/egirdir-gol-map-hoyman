import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Harita tile'larını SQLite veritabanında önbelleğe alan servis.
///
/// Tile'lar ekrana geldiğinde otomatik indirilip kaydedilir.
/// Bir sonraki açılışta (offline dahil) doğrudan bu DB'den okunur.
class SqliteTileCacheService {
  static final SqliteTileCacheService _instance =
      SqliteTileCacheService._internal();
  factory SqliteTileCacheService() => _instance;
  SqliteTileCacheService._internal();

  Database? _db;

  bool get isReady => _db != null;

  /// Veritabanını başlatır. ViewModel.init() içinde çağrılır.
  Future<void> init() async {
    if (kIsWeb) return; // Web'de sqflite desteklenmez
    if (_db != null) return;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docDir.path, 'tile_cache.db');

      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tiles (
              zoom_level  INTEGER NOT NULL,
              tile_column INTEGER NOT NULL,
              tile_row    INTEGER NOT NULL,
              tile_data   BLOB    NOT NULL,
              PRIMARY KEY (zoom_level, tile_column, tile_row)
            )
          ''');
        },
      );
    } catch (e) {
      // Hata durumunda cache devre dışı kalır; uygulama normal çalışır.
      _db = null;
    }
  }

  /// Önbellekte kayıtlı tile byte'larını döner. Yoksa null döner (cache miss).
  Future<Uint8List?> getTile(int zoom, int x, int y) async {
    if (_db == null) return null;
    try {
      final rows = await _db!.query(
        'tiles',
        columns: ['tile_data'],
        where: 'zoom_level = ? AND tile_column = ? AND tile_row = ?',
        whereArgs: [zoom, x, y],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['tile_data'] as Uint8List;
    } catch (_) {
      return null;
    }
  }

  /// İndirilen tile'ı önbelleğe kaydeder. Zaten varsa atlar.
  Future<void> saveTile(int zoom, int x, int y, Uint8List data) async {
    if (_db == null) return;
    try {
      await _db!.insert(
        'tiles',
        {
          'zoom_level': zoom,
          'tile_column': x,
          'tile_row': y,
          'tile_data': data,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (_) {
      // Yazma hatası — yoksay
    }
  }

  /// Önbellek istatistiklerini döner: tile sayısı ve toplam boyut (byte).
  Future<CacheStats> getStats() async {
    if (_db == null) return const CacheStats(tileCount: 0, sizeBytes: 0);
    try {
      final countResult =
          await _db!.rawQuery('SELECT COUNT(*) as cnt FROM tiles');
      final tileCount = (countResult.first['cnt'] as int?) ?? 0;

      final sizeResult = await _db!
          .rawQuery('SELECT SUM(LENGTH(tile_data)) as total FROM tiles');
      final sizeBytes = (sizeResult.first['total'] as int?) ?? 0;

      return CacheStats(tileCount: tileCount, sizeBytes: sizeBytes);
    } catch (_) {
      return const CacheStats(tileCount: 0, sizeBytes: 0);
    }
  }

  /// Tüm tile önbelleğini temizler.
  Future<void> clearAll() async {
    if (_db == null) return;
    try {
      await _db!.delete('tiles');
    } catch (_) {}
  }

  /// Veritabanı bağlantısını kapatır.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

/// Önbellek istatistik modeli.
class CacheStats {
  final int tileCount;
  final int sizeBytes;

  const CacheStats({required this.tileCount, required this.sizeBytes});

  /// Boyutu okunabilir formatta döner.
  String get formattedSize {
    if (sizeBytes == 0) return '0 KB';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
