import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/services/persistent_backup_service.dart';

void main() {
  group('PersistentBackupService', () {
    late Directory tempDir;
    final service = PersistentBackupService();

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('gol_sepet_backup_test');
      PersistentBackupService.baseDirOverride = tempDir;
    });

    tearDown(() {
      PersistentBackupService.baseDirOverride = null;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    BasketModel completedBasket() => BasketModel(
          id: 3,
          name: 'Sepet #3',
          startName: 'Fener',
          endName: 'Sazlık',
          startLatitude: 38.1023,
          startLongitude: 30.9812,
          endLatitude: 38.1101,
          endLongitude: 30.9755,
          startTimestamp: DateTime(2026, 11, 23, 8, 0),
          endTimestamp: DateTime(2026, 11, 23, 8, 42),
          isCompleted: true,
        );

    BasketModel activeBasket() => BasketModel(
          name: 'Aktif Sepet',
          startLatitude: 38.2500,
          startLongitude: 30.9000,
          startTimestamp: DateTime(2026, 11, 23, 9, 15),
        );

    test('exportAll ve loadBackup roundtrip tüm alanları korur', () async {
      final baskets = [completedBasket(), activeBasket()];

      await service.exportAll(baskets);
      final loaded = await service.loadBackup();

      expect(loaded.length, 2);

      final completed = loaded[0];
      expect(completed.id, 3);
      expect(completed.name, 'Sepet #3');
      expect(completed.startName, 'Fener');
      expect(completed.endName, 'Sazlık');
      expect(completed.startLatitude, 38.1023);
      expect(completed.startLongitude, 30.9812);
      expect(completed.endLatitude, 38.1101);
      expect(completed.endLongitude, 30.9755);
      expect(completed.startTimestamp, DateTime(2026, 11, 23, 8, 0));
      expect(completed.endTimestamp, DateTime(2026, 11, 23, 8, 42));
      expect(completed.isCompleted, isTrue);

      final active = loaded[1];
      expect(active.id, isNull);
      expect(active.name, 'Aktif Sepet');
      expect(active.startLatitude, 38.2500);
      expect(active.startLongitude, 30.9000);
      expect(active.endLatitude, isNull);
      expect(active.endLongitude, isNull);
      expect(active.startTimestamp, DateTime(2026, 11, 23, 9, 15));
      expect(active.endTimestamp, isNull);
      expect(active.isCompleted, isFalse);
    });

    test('Yazılan dosya beklenen JSON yapısını taşır', () async {
      await service.exportAll([completedBasket()]);

      final file = File('${tempDir.path}/GolSepetTakip/sepetler.json');
      expect(await file.exists(), isTrue);

      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(json['version'], 1);
      expect(json['exportedAt'], isNotNull);
      final baskets = json['baskets'] as List<dynamic>;
      expect(baskets, hasLength(1));
      expect((baskets.first as Map<String, dynamic>)['startName'], 'Fener');
      expect((baskets.first as Map<String, dynamic>)['id'], 3);
    });

    test('Dosya yoksa loadBackup boş liste döner', () async {
      expect(await service.loadBackup(), isEmpty);
    });

    test('Bozuk JSON içeriğinde loadBackup boş liste döner', () async {
      final file = File('${tempDir.path}/GolSepetTakip/sepetler.json');
      await file.create(recursive: true);
      await file.writeAsString('{"version": 1, "baskets": [ {"name": ');

      expect(await service.loadBackup(), isEmpty);
    });

    test('baskets anahtarı yoksa boş liste döner', () async {
      final file = File('${tempDir.path}/GolSepetTakip/sepetler.json');
      await file.create(recursive: true);
      await file.writeAsString('{"version": 1}');

      expect(await service.loadBackup(), isEmpty);
    });
  });
}
