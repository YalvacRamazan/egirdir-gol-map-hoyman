import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:map/models/basket_model.dart';

/// Sepet verilerini uygulama silinse dahi yaşayan public
/// Documents/GolSepetTakip/sepetler.json dosyasına yazar ve geri yükler.
class PersistentBackupService {
  static final PersistentBackupService _instance =
      PersistentBackupService._internal();
  factory PersistentBackupService() => _instance;
  PersistentBackupService._internal();

  static const _channel = MethodChannel('com.rumata.gol_sepet_takip/storage');

  /// Testlerde yedek dizinini geçici bir klasöre yönlendiren kanca.
  /// Üretimde null kalır; null iken davranış değişmez.
  @visibleForTesting
  static Directory? baseDirOverride;

  Future<Directory> _backupDir() async {
    String base;
    if (baseDirOverride != null) {
      base = baseDirOverride!.path;
    } else if (!kIsWeb && Platform.isAndroid) {
      try {
        base = await _channel.invokeMethod<String>('getPublicDocumentsDir') ??
            (await getApplicationDocumentsDirectory()).path;
      } catch (_) {
        base = (await getApplicationDocumentsDirectory()).path;
      }
    } else {
      base = (await getApplicationDocumentsDirectory()).path;
    }
    final dir = Directory(p.join(base, 'GolSepetTakip'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _backupFile() async =>
      File(p.join((await _backupDir()).path, 'sepetler.json'));

  Future<void> exportAll(List<BasketModel> baskets) async {
    if (kIsWeb) return;
    try {
      final file = await _backupFile();
      final payload = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'baskets': baskets.map(_basketToJson).toList(),
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (e) {
      debugPrint('PersistentBackupService exportAll hatası: $e');
    }
  }

  Future<List<BasketModel>> loadBackup() async {
    if (kIsWeb) return [];
    try {
      final file = await _backupFile();
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final list = json['baskets'] as List<dynamic>? ?? [];
      return list
          .map((e) => _basketFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PersistentBackupService loadBackup hatası: $e');
      return [];
    }
  }

  // JSON anahtarları camelCase; alanlar BasketModel.toMap/fromMap ile aynı,
  // id dahil korunur (geri yüklemede aynı id ile yeniden kurulur).
  Map<String, dynamic> _basketToJson(BasketModel b) => {
        if (b.id != null) 'id': b.id,
        'name': b.name,
        'startName': b.startName,
        'endName': b.endName,
        'startLatitude': b.startLatitude,
        'startLongitude': b.startLongitude,
        'endLatitude': b.endLatitude,
        'endLongitude': b.endLongitude,
        'startTimestamp': b.startTimestamp.toIso8601String(),
        'endTimestamp': b.endTimestamp?.toIso8601String(),
        'isCompleted': b.isCompleted,
      };

  BasketModel _basketFromJson(Map<String, dynamic> json) => BasketModel(
        id: json['id'] as int?,
        name: json['name'] as String,
        startName: json['startName'] as String?,
        endName: json['endName'] as String?,
        startLatitude: (json['startLatitude'] as num).toDouble(),
        startLongitude: (json['startLongitude'] as num).toDouble(),
        endLatitude: (json['endLatitude'] as num?)?.toDouble(),
        endLongitude: (json['endLongitude'] as num?)?.toDouble(),
        startTimestamp: DateTime.parse(json['startTimestamp'] as String),
        endTimestamp: json['endTimestamp'] != null
            ? DateTime.parse(json['endTimestamp'] as String)
            : null,
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
}
