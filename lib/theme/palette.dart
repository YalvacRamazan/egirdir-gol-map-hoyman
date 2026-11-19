import 'package:flutter/material.dart';

/// DESIGN.md paletinin tek merkezi (R-29, R-31, R-34).
///
/// Tüm sabit renkler buradan kullanılır; ekran dosyalarında hex tekrarı
/// bırakılmaz. Tema tarafından yönetilen renkler (scheme.error, onSurface,
/// onSurfaceVariant vb.) için ColorScheme kullanılmaya devam eder.
///
/// Kontrast notları WCAG 2.1 AA eşiğine göredir: normal metin 4.5:1, büyük
/// metin ve arayüz bileşenleri 3:1 (bkz. lib/utils/contrast.dart ve
/// test/contrast_test.dart).
abstract final class Palette {
  /// Çekirdek (birincil): göl mavisi — harita ve birincil eylemler.
  /// Beyaz metinle 5.7:1 (AA normal metin).
  static const Color primary = Color(0xFF1565C0); // blue.shade800

  /// Birincilin koyu tema zeminindeki metin/ikon varyantı (blue.shade300).
  /// Koyu yüzeyde 7.7:1; açık temada kullanılmaz (beyazda yalnızca 2.2:1).
  static const Color primaryOnDark = Color(0xFF64B5F6);

  /// Kullanıcı konum/yön göstergesi (blue.shade600). Hedef yön okunun
  /// birincilinden ayrışır; harita altlığı üzerinde kullanılır.
  /// Beyaz zeminde 3.7:1 (bileşen eşiği 3:1'i geçer).
  static const Color userLocation = Color(0xFF1E88E5);

  /// A noktası (başlangıç): anlamsal, sabit (green.shade800).
  /// Beyaz metinle 5.1:1 (AA normal metin).
  static const Color pointA = Color(0xFF2E7D32);

  /// B noktası (bitiş): anlamsal, sabit (red.shade800).
  /// Beyaz metinle 5.6:1 (AA normal metin).
  static const Color pointB = Color(0xFFC62828);

  /// A noktasının koyu tema zeminindeki metin/ikon varyantı (green.shade300).
  /// Koyu yüzeyde 8.5:1; açık temada kullanılmaz.
  static const Color pointAOnDark = Color(0xFF81C784);

  /// B noktasının koyu tema zeminindeki metin/ikon varyantı (red.shade300).
  /// Koyu yüzeyde 5.7:1; açık temada kullanılmaz.
  static const Color pointBOnDark = Color(0xFFE57373);

  /// Vurgu: yalnızca uyarı ve hata durumları (deepOrange.shade900).
  /// Beyaz metinle 5.6:1 (AA normal metin).
  static const Color accentWarning = Color(0xFFBF360C);

  /// Vurgunun koyu tema zeminindeki metin/ikon varyantı (deepOrange.shade300).
  /// Koyu yüzeyde 7.4:1; açık temada kullanılmaz.
  static const Color accentWarningOnDark = Color(0xFFFF8A65);

  /// Nötr: pasif kontroller (grey.shade700). Beyaz ikonla 6.2:1.
  static const Color neutralMuted = Color(0xFF616161);

  /// Nötr: güçlü pasif yüzey (grey.shade800). Beyaz ikonla 10.0:1.
  static const Color neutralStrong = Color(0xFF424242);

  /// Parlaklığa göre birincil metin/ikon rengini döndürür.
  static Color primaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryOnDark : primary;

  /// Parlaklığa göre A noktası metin/ikon rengini döndürür.
  static Color pointAFor(Brightness brightness) =>
      brightness == Brightness.dark ? pointAOnDark : pointA;

  /// Parlaklığa göre B noktası metin/ikon rengini döndürür.
  static Color pointBFor(Brightness brightness) =>
      brightness == Brightness.dark ? pointBOnDark : pointB;

  /// Parlaklığa göre vurgu metin/ikon rengini döndürür.
  static Color accentWarningFor(Brightness brightness) =>
      brightness == Brightness.dark ? accentWarningOnDark : accentWarning;
}
