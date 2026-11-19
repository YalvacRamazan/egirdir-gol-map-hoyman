// WCAG 2.1 AA eşikleri (DESIGN.md R-25):
// - Normal metin: >= 4.5:1
// - Büyük metin (>= 18pt ya da >= 14pt bold) ve arayüz bileşenleri: >= 3.0:1
//
// Durum rozetleri "koyu zemin + beyaz metin" kalıbını kullanır; bu testler
// rozet zeminlerinin beyaz metinle normal metin eşiğini geçtiğini ve koyu
// temada A/B/vurgu metin-ikon varyantlarının (OnDark) koyu yüzeyde
// okunabilir olduğunu doğrular.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/theme/palette.dart';
import 'package:map/utils/contrast.dart';

/// Material 3 varsayılan koyu tema yüzeyine yakın temsilî koyu zemin.
const Color _darkSurface = Color(0xFF1C1B1F);

void main() {
  group('contrastRatio hesabı', () {
    test('siyah/beyaz 21:1 dir', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.1));
    });

    test('aynı renk 1:1 dir', () {
      expect(
        contrastRatio(Palette.primary, Palette.primary),
        closeTo(1.0, 1e-9),
      );
    });

    test('parametre sırasından bağımsızdır', () {
      expect(
        contrastRatio(Colors.white, Palette.primary),
        closeTo(contrastRatio(Palette.primary, Colors.white), 1e-9),
      );
    });
  });

  group('Palet kimliği — DESIGN.md hex değerleri', () {
    test('çekirdek, anlamsal ve vurgu renkleri', () {
      expect(Palette.primary, const Color(0xFF1565C0)); // blue.shade800
      expect(Palette.pointA, const Color(0xFF2E7D32)); // green.shade800
      expect(Palette.pointB, const Color(0xFFC62828)); // red.shade800
      expect(Palette.accentWarning, const Color(0xFFBF360C));
    });

    test('parlaklığa göre varyant seçimi', () {
      expect(Palette.primaryFor(Brightness.light), Palette.primary);
      expect(Palette.primaryFor(Brightness.dark), Palette.primaryOnDark);
      expect(Palette.pointAFor(Brightness.light), Palette.pointA);
      expect(Palette.pointAFor(Brightness.dark), Palette.pointAOnDark);
      expect(Palette.pointBFor(Brightness.light), Palette.pointB);
      expect(Palette.pointBFor(Brightness.dark), Palette.pointBOnDark);
      expect(
        Palette.accentWarningFor(Brightness.light),
        Palette.accentWarning,
      );
      expect(
        Palette.accentWarningFor(Brightness.dark),
        Palette.accentWarningOnDark,
      );
    });
  });

  group('Açık tema: beyaz metin palet zeminlerinde (normal metin 4.5)', () {
    // Durum rozetleri ve dolu düğmeler: koyu zemin + beyaz metin kalıbı.
    test('beyaz / primary (#1565C0) >= 4.5', () {
      expect(
        contrastRatio(Colors.white, Palette.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('beyaz / pointA (#2E7D32) >= 4.5', () {
      expect(
        contrastRatio(Colors.white, Palette.pointA),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('beyaz / pointB (#C62828) >= 4.5', () {
      expect(
        contrastRatio(Colors.white, Palette.pointB),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('beyaz / accentWarning (#BF360C) >= 4.5', () {
      expect(
        contrastRatio(Colors.white, Palette.accentWarning),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Koyu tema: OnDark varyantları koyu zeminde (normal metin 4.5)', () {
    test('primaryOnDark / koyu zemin >= 4.5', () {
      expect(
        contrastRatio(Palette.primaryOnDark, _darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('pointAOnDark / koyu zemin >= 4.5', () {
      expect(
        contrastRatio(Palette.pointAOnDark, _darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('pointBOnDark / koyu zemin >= 4.5', () {
      expect(
        contrastRatio(Palette.pointBOnDark, _darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('accentWarningOnDark / koyu zemin >= 4.5', () {
      expect(
        contrastRatio(Palette.accentWarningOnDark, _darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Büyük metin ve arayüz bileşeni eşiği (3.0)', () {
    test('primary harita altlığı (beyaz) üzerinde >= 3.0', () {
      expect(
        contrastRatio(Palette.primary, Colors.white),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('pointA beyaz zeminde >= 3.0', () {
      expect(
        contrastRatio(Palette.pointA, Colors.white),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('pointB beyaz zeminde >= 3.0', () {
      expect(
        contrastRatio(Palette.pointB, Colors.white),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('accentWarning beyaz zeminde >= 3.0', () {
      expect(
        contrastRatio(Palette.accentWarning, Colors.white),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('userLocation (kullanıcı yön oku) beyaz zeminde >= 3.0', () {
      expect(
        contrastRatio(Palette.userLocation, Colors.white),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('nötr pasif düğme zemininde beyaz ikon >= 3.0', () {
      expect(
        contrastRatio(Colors.white, Palette.neutralMuted),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        contrastRatio(Colors.white, Palette.neutralStrong),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  group('Gerçek koyu tema (ColorScheme.fromSeed) yüzeyinde okunabilirlik', () {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Palette.primary,
      brightness: Brightness.dark,
    );

    test('primaryOnDark scheme.surface üzerinde >= 4.5', () {
      expect(
        contrastRatio(Palette.primaryOnDark, darkScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('pointAOnDark scheme.surface üzerinde >= 4.5', () {
      expect(
        contrastRatio(Palette.pointAOnDark, darkScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('pointBOnDark scheme.surface üzerinde >= 4.5', () {
      expect(
        contrastRatio(Palette.pointBOnDark, darkScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('accentWarningOnDark scheme.surface üzerinde >= 4.5', () {
      expect(
        contrastRatio(Palette.accentWarningOnDark, darkScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
