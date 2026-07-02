import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:map/models/basket_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  
  // Web için geçici bellek içi depolama
  final List<BasketModel> _webBaskets = [];
  int _webNextId = 1; // Güvenli ID üretici (uzunluğa bağlı değil)

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gol_sepet_takip.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE baskets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
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

  // --- CRUD İşlemleri ---

  /// Yeni bir sepet ekler
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

  /// Mevcut sepeti günceller
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

  /// Tüm sepetleri listeler
  Future<List<BasketModel>> getAllBaskets() async {
    if (kIsWeb) {
      // En yeni eklenen en üstte olacak şekilde sırala
      return List.from(_webBaskets.reversed);
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'baskets',
      orderBy: 'start_timestamp DESC',
    );
    return List.generate(maps.length, (i) => BasketModel.fromMap(maps[i]));
  }

  /// Tamamlanmamış sepetleri döner
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

  /// Tek bir sepeti ID ile sorgular
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

  /// Sepeti veritabanından siler
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

  /// Tüm veritabanını temizler
  Future<void> clearDatabase() async {
    if (kIsWeb) {
      _webBaskets.clear();
      return;
    }
    final db = await database;
    await db!.delete('baskets');
  }
}
