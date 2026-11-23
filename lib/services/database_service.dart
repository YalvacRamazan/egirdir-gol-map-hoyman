import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:map/models/basket_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static Future<Database>? _databaseFuture;
  
  final List<BasketModel> _webBaskets = [];
  int _webNextId = 1;

  Future<Database?> get database async {
    if (kIsWeb) return null;
    return _database ??= await (_databaseFuture ??= _initDatabase());
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gol_sepet_takip.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE baskets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_name TEXT,
        end_name TEXT,
        start_latitude REAL NOT NULL,
        start_longitude REAL NOT NULL,
        end_latitude REAL,
        end_longitude REAL,
        start_timestamp TEXT NOT NULL,
        end_timestamp TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE baskets ADD COLUMN start_name TEXT');
      await db.execute('ALTER TABLE baskets ADD COLUMN end_name TEXT');
    }
  }

  Future<int> insertBasket(BasketModel basket) async {
    if (kIsWeb) {
      final id = _webNextId++;
      final newBasket = basket.copyWith(id: id);
      _webBaskets.add(newBasket);
      return id;
    }
    
    final db = await database;
    return await db!.insert(
      'baskets',
      basket.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateBasket(BasketModel basket) async {
    if (basket.id == null) return 0;
    
    if (kIsWeb) {
      final index = _webBaskets.indexWhere((b) => b.id == basket.id);
      if (index != -1) {
        _webBaskets[index] = basket;
        return 1;
      }
      return 0;
    }

    final db = await database;
    return await db!.update(
      'baskets',
      basket.toMap(),
      where: 'id = ?',
      whereArgs: [basket.id],
    );
  }

  Future<List<BasketModel>> getAllBaskets() async {
    if (kIsWeb) {
      return List.from(_webBaskets.reversed);
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'baskets',
      orderBy: 'start_timestamp DESC',
    );
    return List.generate(maps.length, (i) => BasketModel.fromMap(maps[i]));
  }

  Future<List<BasketModel>> getActiveBaskets() async {
    if (kIsWeb) {
      return _webBaskets.where((b) => !b.isCompleted).toList();
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'baskets',
      where: 'is_completed = ?',
      whereArgs: [0],
      orderBy: 'start_timestamp DESC',
    );
    return List.generate(maps.length, (i) => BasketModel.fromMap(maps[i]));
  }

  Future<BasketModel?> getBasketById(int id) async {
    if (kIsWeb) {
      final results = _webBaskets.where((b) => b.id == id);
      return results.isEmpty ? null : results.first;
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'baskets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return BasketModel.fromMap(maps.first);
  }

  Future<int> deleteBasket(int id) async {
    if (kIsWeb) {
      final initialLength = _webBaskets.length;
      _webBaskets.removeWhere((b) => b.id == id);
      return initialLength - _webBaskets.length;
    }

    final db = await database;
    return await db!.delete(
      'baskets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearDatabase() async {
    if (kIsWeb) {
      _webBaskets.clear();
      return;
    }
    final db = await database;
    await db!.delete('baskets');
  }

  /// JSON yedeğinden geri yükleme: aynı id'lerle sepetleri yeniden kurar.
  Future<void> restoreBaskets(List<BasketModel> baskets) async {
    if (kIsWeb) {
      _webBaskets.addAll(baskets);
      return;
    }
    final db = await database;
    final batch = db!.batch();
    for (final b in baskets) {
      batch.insert(
        'baskets',
        b.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
