import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:map/models/basket_model.dart';

/// Sepet verilerini uygulama özel belgeler dizinindeki
/// GolSepetTakip/sepetler.json dosyasına yazar ve geri yükler.
/// Dizin işletim sistemi koruması altındadır; dışa aktarma kullanıcı
/// başlatmalı paylaşım akışıyla (ShareService.shareBackup) yapılır.
class PersistentBackupService {
  static final PersistentBackupService _instance =
      PersistentBackupService._internal();
  factory PersistentBackupService() => _instance;
  PersistentBackupService._internal();

  /// Testlerde yedek dizinini geçici bir klasöre yönlendiren kanca.
  /// Üretimde null kalır; null iken davranış değişmez.
  @visibleForTesting
  static Directory? baseDirOverride;

  Future<Directory> _backupDir() async {
    final base = baseDirOverride?.path ??
        (await getApplicationDocumentsDirectory()).path;
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
      if (kDebugMode) {
        debugPrint('PersistentBackupService exportAll hatası: $e');
      }
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
          .map((e) => _tryBasketFromJson(e as Map<String, dynamic>))
          .whereType<BasketModel>()
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PersistentBackupService loadBackup hatası: $e');
      }
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

  /// Yedek kaydını doğrulayıp dönüştürür; geçersiz kayıtlar atlanır.
  BasketModel? _tryBasketFromJson(Map<String, dynamic> json) {
    try {
      final name = json['name'];
      final startLatitude = (json['startLatitude'] as num?)?.toDouble();
      final startLongitude = (json['startLongitude'] as num?)?.toDouble();
      final startTimestampJson = json['startTimestamp'];

      if (name is! String || name.trim().isEmpty) return null;
      if (startLatitude == null || startLongitude == null) return null;
      if (!_isValidLatitude(startLatitude) ||
          !_isValidLongitude(startLongitude)) {
        return null;
      }
      if (startTimestampJson is! String) return null;
      final startTimestamp = DateTime.tryParse(startTimestampJson);
      if (startTimestamp == null) return null;

      final endLatitude = (json['endLatitude'] as num?)?.toDouble();
      final endLongitude = (json['endLongitude'] as num?)?.toDouble();
      if (endLatitude != null && !_isValidLatitude(endLatitude)) return null;
      if (endLongitude != null && !_isValidLongitude(endLongitude)) return null;

      DateTime? endTimestamp;
      final endTimestampJson = json['endTimestamp'];
      if (endTimestampJson != null) {
        if (endTimestampJson is! String) return null;
        endTimestamp = DateTime.tryParse(endTimestampJson);
        if (endTimestamp == null) return null;
      }

      return BasketModel(
        id: json['id'] as int?,
        name: name,
        startName: json['startName'] as String?,
        endName: json['endName'] as String?,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        endLatitude: endLatitude,
        endLongitude: endLongitude,
        startTimestamp: startTimestamp,
        endTimestamp: endTimestamp,
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isValidLatitude(double value) => value >= -90 && value <= 90;

  static bool _isValidLongitude(double value) => value >= -180 && value <= 180;
}
