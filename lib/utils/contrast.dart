import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.1 bağıl parlaklığı: 0 (siyah) - 1 (beyaz) aralığında.
///
/// Formül: https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
/// Girdi kanalları, Flutter'ın 0-1 aralığındaki renk bileşenleridir.
double relativeLuminance(Color color) {
  // Gama öncesi kanalı doğrusal ışık uzayına taşır.
  double linearize(double channel) {
    return channel <= 0.03928
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linearize(color.r);
  final g = linearize(color.g);
  final b = linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// İki renk arasındaki WCAG kontrast oranı (1.0 - 21.0 aralığında).
///
/// Eşikler (WCAG 2.1 AA, DESIGN.md R-25):
/// - Normal metin: >= 4.5
/// - Büyük metin (>= 18pt ya da >= 14pt bold) ve arayüz bileşenleri: >= 3.0
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}
