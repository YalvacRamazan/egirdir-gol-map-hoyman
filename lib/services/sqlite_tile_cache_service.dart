import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Harita tile'larını SQLite veritabanında önbelleğe alan servis.
///
/// Tile'lar ekrana geldiğinde otomatik indirilip kaydedilir.
/// Bir sonraki açılışta (offline dahil) doğrudan bu DB'den okunur.
///
/// Önbellek sınırları (sabit; ayar ekranından değiştirilmez):
///   - [maxCacheBytes] = 50 MB toplam disk kullanımı
///   - [maxCacheAge]   = 30 gün tile yaşı
///
/// [saveTile] her kayıttan sonra [evictIfNeeded]'i tetikler:
///   1. Yaşı [maxCacheAge]'i aşan tile'lar silinir.
///   2. Toplam boyut hâlâ [maxCacheBytes]'i aşıyorsa en eski yazılandan
///      başlayarak sınırın altına inene kadar silinir (LRU-benzeri).
///
/// Tasarım notları:
///   - Okuma ([getTile]) sırasında timestamp güncellenmez: her okumada
///     yazma, düşük donanımda gereksiz I/O yüküdür. "Son erişim" yerine
///     "son yazma" zamanı kullanılır; yeniden indirilen tile'lar
///     (ConflictAlgorithm.replace ile upsert) taze sayılır.
///   - Silme sonrası VACUUM çalıştırılmaz: SQLite boşalan sayfaları
///     yeniden kullanır; VACUUM düşük donanımda pahalı ve uzundur.
///   - v1 migration'ından gelen satırlar timestamp=0 ile işaretlenir ve
///     ilk eviction'da "en eski" olarak temizlenir.
class SqliteTileCacheService {
  static final SqliteTileCacheService _instance =
      SqliteTileCacheService._internal();
  factory SqliteTileCacheService() => _instance;
  SqliteTileCacheService._internal();

  /// Önbellek disk sınırı: 50 MB.
  static const int maxCacheBytes = 50 * 1024 * 1024;

  /// Tile yaş sınırı: 30 gün.
  static const Duration maxCacheAge = Duration(days: 30);

  static const int _dbVersion = 2;

  Database? _db;

  /// Yazma işlemlerini sıraya alan basit kilit: save+evict akışının
  /// yarış koşulu olmadan sıralı yürütülmesini sağlar.
  Future<void> _writeQueue = Future.value();

  /// Eşzamanlı eviction çalıştırmasını önleyen bayrak.
  bool _evictionInProgress = false;

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
              PRIMARY KEY (zoom_level, tile_column, tile_row)
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // v1 → v2: timestamp ve size kolonları eklenir.
          // v1 satırlarında yazma zamanı bilinmediği için timestamp=0
          // (en eski → ilk eviction'da temizlenir), size ise blob
          // uzunluğuyla doldurulur.
          if (oldVersion < 2) {
            await db.execute(
                'ALTER TABLE tiles ADD COLUMN timestamp INTEGER NOT NULL DEFAULT 0');
            await db.execute(
                'ALTER TABLE tiles ADD COLUMN size INTEGER NOT NULL DEFAULT 0');
            await db.execute('UPDATE tiles SET size = LENGTH(tile_data)');
          }
        },
      );
    } catch (_) {
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

  /// İndirilen tile'ı önbelleğe kaydeder ve ardından [evictIfNeeded]'i
  /// çalıştırır.
  ///
  /// Aynı tile tekrar yazılırsa satır REPLACE edilir; böylece timestamp
  /// güncellenir ve tile "taze" sayılır (LRU-benzeri davranış).
  Future<void> saveTile(int zoom, int x, int y, Uint8List data) {
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
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {
        // Yazma hatası: yoksay
      }
      await evictIfNeeded();
    });
  }

  /// Yazma işlemlerini sıraya alır; kuyruk hata sonrası da ilerlemeye
  /// devam eder.
  Future<T> _enqueue<T>(Future<T> Function() task) {
    final run = _writeQueue.then((_) => task());
    _writeQueue = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// Önbellek sınırlarını denetler ve gereken tile'ları siler.
  ///
  /// Seçim mantığı saf fonksiyon [selectTileIdsToEvict]'te yer alır;
  /// bu metot yalnızca DB okuma/silme işlemlerini yürütür.
  Future<void> evictIfNeeded() async {
    final db = _db;
    if (db == null) return;
    if (_evictionInProgress) return;
    _evictionInProgress = true;
    try {
      final rows =
          await db.rawQuery('SELECT rowid AS id, timestamp, size FROM tiles');
      final tiles = rows.map(TileMeta.fromRow).toList();
      final ids = selectTileIdsToEvict(
        tiles,
        maxCacheBytes,
        DateTime.now(),
        maxCacheAge,
      );
      if (ids.isEmpty) return;

      // Silme işlemini parçalara bölerek tek dev sorguyu önle.
      const chunkSize = 256;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.skip(i).take(chunkSize).toList();
        await db.delete(
          'tiles',
          where: 'rowid IN (${List.filled(chunk.length, '?').join(', ')})',
          whereArgs: chunk,
        );
      }
    } catch (_) {
      // Eviction hatası: yoksay; önbellek çalışmaya devam eder.
    } finally {
      _evictionInProgress = false;
    }
  }

  /// Önbellek istatistiklerini döner: tile sayısı, toplam boyut (byte)
  /// ve en eski/en yeni tile yazma zamanları (ms epoch; boş önbellekte null).
  Future<CacheStats> getStats() async {
    if (_db == null) return const CacheStats(tileCount: 0, sizeBytes: 0);
    try {
      final result = await _db!.rawQuery('''
        SELECT COUNT(*) AS cnt,
               SUM(size) AS total,
               MIN(timestamp) AS oldest,
               MAX(timestamp) AS newest
        FROM tiles
      ''');
      final row = result.first;
      return CacheStats(
        tileCount: (row['cnt'] as int?) ?? 0,
        sizeBytes: (row['total'] as int?) ?? 0,
        oldestTimestamp: row['oldest'] as int?,
        newestTimestamp: row['newest'] as int?,
      );
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

/// Eviction kararları için bir tile'ın minimum meta verisi.
class TileMeta {
  /// SQLite rowid.
  final int id;

  /// Son yazma zamanı (ms epoch). v1 migration satırlarında 0.
  final int timestamp;

  /// Blob byte uzunluğu.
  final int size;

  const TileMeta({
    required this.id,
    required this.timestamp,
    required this.size,
  });

  factory TileMeta.fromRow(Map<String, Object?> row) => TileMeta(
        id: (row['id'] as num).toInt(),
        timestamp: (row['timestamp'] as int?) ?? 0,
        size: (row['size'] as int?) ?? 0,
      );
}

/// Eviction seçim mantığı (saf fonksiyon; DB'ye bağımsız, test edilebilir).
///
/// Kurallar sırayla uygulanır:
///   1. Yaş aşımı: `timestamp < now - maxAge` olan tile'lar silinir.
///   2. Boyut aşımı: kalan tile'ların toplam boyutu `maxBytes`'i aşarsa,
///      en eski yazılandan başlayarak toplam sınırın altına inene kadar
///      silinir.
///
/// Dönen liste silinecek tile id'leridir; her iki grup da en eskiden
/// yeniye timestamp sırasıyla döner.
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

/// Önbellek istatistik modeli.
class CacheStats {
  final int tileCount;
  final int sizeBytes;

  /// En eski tile'ın yazılma zamanı (ms epoch). Boş önbellekte null.
  final int? oldestTimestamp;

  /// En yeni tile'ın yazılma zamanı (ms epoch). Boş önbellekte null.
  final int? newestTimestamp;

  const CacheStats({
    required this.tileCount,
    required this.sizeBytes,
    this.oldestTimestamp,
    this.newestTimestamp,
  });

  /// Boyutu okunabilir formatta döner.
  String get formattedSize {
    if (sizeBytes == 0) return '0 KB';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
