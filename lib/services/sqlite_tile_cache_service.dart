import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class SqliteTileCacheService {
  static final SqliteTileCacheService _instance =
      SqliteTileCacheService._internal();
  factory SqliteTileCacheService() => _instance;
  SqliteTileCacheService._internal();

  static const int maxCacheBytes = 50 * 1024 * 1024;

  static const Duration maxCacheAge = Duration(days: 30);

  static const int _dbVersion = 3;

  Database? _db;

  Future<void> _writeQueue = Future.value();

  bool _evictionInProgress = false;

  bool get isReady => _db != null;

  Future<void> init() async {
    if (kIsWeb) return;
    if (_db != null) return;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docDir.path, 'tile_cache.db');

      _db = await openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tiles (
              zoom_level  INTEGER NOT NULL,
              tile_column INTEGER NOT NULL,
              tile_row    INTEGER NOT NULL,
              tile_data   BLOB    NOT NULL,
              timestamp   INTEGER NOT NULL,
              size        INTEGER NOT NULL,
              is_permanent INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (zoom_level, tile_column, tile_row)
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _addColumnIfMissing(
                db, 'timestamp', 'INTEGER NOT NULL DEFAULT 0');
            await _addColumnIfMissing(
                db, 'size', 'INTEGER NOT NULL DEFAULT 0');
            await db.execute('UPDATE tiles SET size = LENGTH(tile_data)');
          }
          if (oldVersion < 3) {
            await _addColumnIfMissing(
                db, 'is_permanent', 'INTEGER NOT NULL DEFAULT 0');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SqliteTileCacheService init: veritabanı açılamadı: $e');
      }
      _db = null;
    }
  }

  /// Sütun yoksa ekler; tekrar çalışan migration'ları idempotent yapar.
  static Future<void> _addColumnIfMissing(
    Database db,
    String column,
    String definition,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info(tiles)');
    final exists = rows.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE tiles ADD COLUMN $column $definition');
    }
  }

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

  Future<void> saveTile(
    int zoom,
    int x,
    int y,
    Uint8List data, {
    bool permanent = false,
  }) {
    if (_db == null) return Future.value();
    return _enqueue(() async {
      try {
        await _db!.insert(
          'tiles',
          {
            'zoom_level': zoom,
            'tile_column': x,
            'tile_row': y,
            'tile_data': data,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'size': data.length,
            'is_permanent': permanent ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {
      }
      await evictIfNeeded();
    });
  }

  /// Tile önbellekte var mı (indirme atlama kontrolü için).
  Future<bool> hasTile(int zoom, int x, int y) async {
    if (_db == null) return false;
    try {
      final rows = await _db!.query(
        'tiles',
        columns: ['zoom_level'],
        where: 'zoom_level = ? AND tile_column = ? AND tile_row = ?',
        whereArgs: [zoom, x, y],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final run = _writeQueue.then((_) => task());
    _writeQueue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<void> evictIfNeeded() async {
    final db = _db;
    if (db == null) return;
    if (_evictionInProgress) return;
    _evictionInProgress = true;
    try {
      final rows = await db.rawQuery(
          'SELECT rowid AS id, timestamp, size FROM tiles WHERE is_permanent = 0');
      final tiles = rows.map(TileMeta.fromRow).toList();
      final ids = selectTileIdsToEvict(
        tiles,
        maxCacheBytes,
        DateTime.now(),
        maxCacheAge,
      );
      if (ids.isEmpty) return;

      const chunkSize = 256;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.skip(i).take(chunkSize).toList();
        await db.delete(
          'tiles',
          where:
              'rowid IN (${List.filled(chunk.length, '?').join(', ')}) AND is_permanent = 0',
          whereArgs: chunk,
        );
      }
    } catch (_) {
    } finally {
      _evictionInProgress = false;
    }
  }

  Future<CacheStats> getStats() async {
    if (_db == null) return const CacheStats(tileCount: 0, sizeBytes: 0);
    try {
      final result = await _db!.rawQuery('''
        SELECT is_permanent AS permanent,
               COUNT(*) AS cnt,
               SUM(size) AS total,
               MIN(timestamp) AS oldest,
               MAX(timestamp) AS newest
        FROM tiles
        GROUP BY is_permanent
      ''');
      var tileCount = 0;
      var sizeBytes = 0;
      var permanentTileCount = 0;
      var permanentSizeBytes = 0;
      int? oldest;
      int? newest;
      for (final row in result) {
        final cnt = (row['cnt'] as int?) ?? 0;
        final total = (row['total'] as int?) ?? 0;
        tileCount += cnt;
        sizeBytes += total;
        if ((row['permanent'] as int?) == 1) {
          permanentTileCount = cnt;
          permanentSizeBytes = total;
        }
        final rowOldest = row['oldest'] as int?;
        final rowNewest = row['newest'] as int?;
        if (rowOldest != null && (oldest == null || rowOldest < oldest)) {
          oldest = rowOldest;
        }
        if (rowNewest != null && (newest == null || rowNewest > newest)) {
          newest = rowNewest;
        }
      }
      return CacheStats(
        tileCount: tileCount,
        sizeBytes: sizeBytes,
        oldestTimestamp: oldest,
        newestTimestamp: newest,
        permanentTileCount: permanentTileCount,
        permanentSizeBytes: permanentSizeBytes,
      );
    } catch (_) {
      return const CacheStats(tileCount: 0, sizeBytes: 0);
    }
  }

  Future<void> clearAll() async {
    if (_db == null) return;
    try {
      await _db!.delete('tiles');
    } catch (_) {}
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

class TileMeta {
  final int id;

  final int timestamp;

  final int size;

  final bool isPermanent;

  const TileMeta({
    required this.id,
    required this.timestamp,
    required this.size,
    this.isPermanent = false,
  });

  factory TileMeta.fromRow(Map<String, Object?> row) => TileMeta(
        id: (row['id'] as num).toInt(),
        timestamp: (row['timestamp'] as int?) ?? 0,
        size: (row['size'] as int?) ?? 0,
        isPermanent: (row['is_permanent'] as int?) == 1,
      );
}

List<int> selectTileIdsToEvict(
  List<TileMeta> tiles,
  int maxBytes,
  DateTime now,
  Duration maxAge,
) {
  final cutoff = now.millisecondsSinceEpoch - maxAge.inMilliseconds;

  final expired = <TileMeta>[];
  final survivors = <TileMeta>[];
  var survivorBytes = 0;
  for (final tile in tiles) {
    if (tile.isPermanent) continue;
    if (tile.timestamp < cutoff) {
      expired.add(tile);
    } else {
      survivors.add(tile);
      survivorBytes += tile.size;
    }
  }

  final overLimit = <TileMeta>[];
  if (survivorBytes > maxBytes) {
    survivors.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final tile in survivors) {
      if (survivorBytes <= maxBytes) break;
      overLimit.add(tile);
      survivorBytes -= tile.size;
    }
  }

  expired.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return [
    ...expired.map((t) => t.id),
    ...overLimit.map((t) => t.id),
  ];
}

class CacheStats {
  final int tileCount;
  final int sizeBytes;

  final int? oldestTimestamp;

  final int? newestTimestamp;

  final int permanentTileCount;

  final int permanentSizeBytes;

  const CacheStats({
    required this.tileCount,
    required this.sizeBytes,
    this.oldestTimestamp,
    this.newestTimestamp,
    this.permanentTileCount = 0,
    this.permanentSizeBytes = 0,
  });

  String get formattedSize {
    if (sizeBytes == 0) return '0 KB';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
