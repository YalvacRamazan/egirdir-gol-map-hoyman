import 'package:flutter_test/flutter_test.dart';
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
}
