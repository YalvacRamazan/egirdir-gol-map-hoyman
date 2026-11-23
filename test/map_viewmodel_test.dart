import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map/models/basket_model.dart';
import 'package:map/viewmodels/map_viewmodel.dart';

/// MapViewModel seçim modu state testleri.
///
/// Not: setPointA/setPointB/renamePointA/renamePointB metotları
/// DatabaseService (sqflite) bağımlılığı nedeniyle bu test dosyasında
/// kapsanmaz; sqflite platform kanalı birim test ortamında yoktur.
/// Bu metotlar cihaz üzerinde manuel akış testiyle doğrulanır.
void main() {
  group('MapViewModel nokta seçim modu testleri', () {
    test('Başlangıçta seçim modu none olmalıdır', () {
      final vm = MapViewModel();
      expect(vm.selectionMode, MapPointSelectionMode.none);
    });

    test('startSelectingA modu selectA yapmalıdır', () {
      final vm = MapViewModel();
      vm.startSelectingA();
      expect(vm.selectionMode, MapPointSelectionMode.selectA);
    });

    test('startSelectingB modu selectB yapmalıdır', () {
      final vm = MapViewModel();
      vm.startSelectingB();
      expect(vm.selectionMode, MapPointSelectionMode.selectB);
    });

    test('Aynı mod tekrar başlatılırsa iptal edilmelidir (toggle)', () {
      final vm = MapViewModel();
      vm.startSelectingA();
      vm.startSelectingA();
      expect(vm.selectionMode, MapPointSelectionMode.none);

      vm.startSelectingB();
      vm.startSelectingB();
      expect(vm.selectionMode, MapPointSelectionMode.none);
    });

    test('cancelSelection aktif modu none yapmalıdır', () {
      final vm = MapViewModel();
      vm.startSelectingA();
      vm.cancelSelection();
      expect(vm.selectionMode, MapPointSelectionMode.none);
    });

    test('cancelSelection none iken modu bozmamalıdır', () {
      final vm = MapViewModel();
      vm.cancelSelection();
      expect(vm.selectionMode, MapPointSelectionMode.none);
    });

    test('A modundan B moduna geçiş yapılabilmelidir', () {
      final vm = MapViewModel();
      vm.startSelectingA();
      vm.startSelectingB();
      expect(vm.selectionMode, MapPointSelectionMode.selectB);
    });

    test('Mod değişikliği dinleyicileri bilgilendirmelidir', () {
      final vm = MapViewModel();
      var notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.startSelectingA();
      vm.cancelSelection();
      // none iken cancelSelection notify yapmamalıdır
      vm.cancelSelection();

      expect(notifyCount, 2);
    });
  });

  group('MapViewModel takip modu testleri', () {
    test('isFollowMode başlangıçta kapalı olmalıdır', () {
      final vm = MapViewModel();
      expect(vm.isFollowMode, isFalse);
    });

    test('setFollowMode modu açıp kapatmalıdır', () {
      final vm = MapViewModel();
      vm.setFollowMode(true);
      expect(vm.isFollowMode, isTrue);
      vm.setFollowMode(false);
      expect(vm.isFollowMode, isFalse);
    });

    test('setFollowMode aynı değere ayarlanırsa bildirim yapmamalıdır', () {
      final vm = MapViewModel();
      var notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.setFollowMode(true);
      vm.setFollowMode(true);
      expect(notifyCount, 1);
    });
  });

  group('MapViewModel hedef nokta testleri', () {
    Position positionAt(double lat, double lon) {
      return Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    BasketModel completedBasket() => BasketModel(
          id: 5,
          name: 'Tamamlanan Sepet',
          startLatitude: 38.1000,
          startLongitude: 30.9800,
          endLatitude: 38.1100,
          endLongitude: 30.9900,
          startTimestamp: DateTime(2026, 1, 1, 8, 0),
          endTimestamp: DateTime(2026, 1, 1, 8, 30),
          isCompleted: true,
        );

    test('Seçili tamamlanmış sepette en yakın uç hedef olur', () {
      final vm = MapViewModel();
      vm.selectBasket(completedBasket());

      final nearB = vm.resolveTargetPoint(positionAt(38.1099, 30.9899));
      expect(nearB, isNotNull);
      expect(nearB!.isStart, isFalse);
      expect(nearB.lat, 38.1100);
      expect(nearB.lon, 30.9900);

      final nearA = vm.resolveTargetPoint(positionAt(38.1001, 30.9801));
      expect(nearA, isNotNull);
      expect(nearA!.isStart, isTrue);
      expect(nearA.lat, 38.1000);
    });

    test('Konum veya seçili sepet yoksa hedef null olmalıdır', () {
      final vm = MapViewModel();
      expect(vm.resolveTargetPoint(null), isNull);
      expect(vm.resolveTargetPoint(positionAt(38.1, 30.98)), isNull);
    });
  });
}
