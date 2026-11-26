import 'package:flutter_test/flutter_test.dart';
import 'package:map/viewmodels/map_viewmodel.dart';

void main() {
  final base = DateTime(2026, 1, 1, 12, 0, 0);

  group('headingDelta', () {
    test('aynı açı 0 döner', () {
      expect(headingDelta(45, 45), 0);
    });

    test('küçük fark korunur', () {
      expect(headingDelta(10, 12), 2);
      expect(headingDelta(12, 10), 2);
    });

    test('359-1 sınırında en kısa fark 2 derecedir', () {
      expect(headingDelta(359, 1), 2);
      expect(headingDelta(1, 359), 2);
    });

    test('180 farkı 180 döner', () {
      expect(headingDelta(0, 180), 180);
    });
  });

  group('shouldEmitHeading', () {
    test('ilk bildirim (lastNotified null) hemen yayınlanır', () {
      final decision = shouldEmitHeading(
        lastNotified: null,
        current: 90,
        lastNotifyAt: base,
        now: base,
      );
      expect(decision.emitNow, isTrue);
    });

    test('yeterli açı değişimi ve süre varsa hemen yayınlanır', () {
      final decision = shouldEmitHeading(
        lastNotified: 90,
        current: 120,
        lastNotifyAt: base,
        now: base.add(const Duration(milliseconds: 150)),
      );
      expect(decision.emitNow, isTrue);
    });

    test('açı değişimi yetersizse yayınlanmaz ve trailing bekler', () {
      final decision = shouldEmitHeading(
        lastNotified: 90,
        current: 90.5,
        lastNotifyAt: base,
        now: base.add(const Duration(milliseconds: 150)),
      );
      expect(decision.emitNow, isFalse);
      expect(decision.waitBeforeTrailing, Duration.zero);
    });

    test('süre yetersizse yayınlanmaz ve kalan süre trailing beklemesidir',
        () {
      final decision = shouldEmitHeading(
        lastNotified: 90,
        current: 120,
        lastNotifyAt: base,
        now: base.add(const Duration(milliseconds: 40)),
      );
      expect(decision.emitNow, isFalse);
      expect(
        decision.waitBeforeTrailing,
        const Duration(milliseconds: 60),
      );
    });

    test('açı değişimi tam eşik değerinde yayınlanır', () {
      final decision = shouldEmitHeading(
        lastNotified: 90,
        current: 91,
        lastNotifyAt: base,
        now: base.add(const Duration(milliseconds: 100)),
      );
      expect(decision.emitNow, isTrue);
    });

    test('360 derece tam tur aynı açı sayılır (yayınlanmaz)', () {
      final decision = shouldEmitHeading(
        lastNotified: 90,
        current: 450,
        lastNotifyAt: base,
        now: base.add(const Duration(milliseconds: 150)),
      );
      expect(decision.emitNow, isFalse);
    });
  });
}
