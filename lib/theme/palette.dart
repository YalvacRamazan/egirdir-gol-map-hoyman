import 'package:flutter/material.dart';

abstract final class Palette {
  static const Color primary = Color(0xFF1565C0);

  static const Color primaryOnDark = Color(0xFF64B5F6);

  static const Color userLocation = Color(0xFF1E88E5);

  static const Color pointA = Color(0xFF2E7D32);

  static const Color pointB = Color(0xFFC62828);

  static const Color pointAOnDark = Color(0xFF81C784);

  static const Color pointBOnDark = Color(0xFFE57373);

  static const Color accentWarning = Color(0xFFBF360C);

  static const Color accentWarningOnDark = Color(0xFFFF8A65);

  static const Color neutralMuted = Color(0xFF616161);

  static const Color neutralStrong = Color(0xFF424242);

  static Color primaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryOnDark : primary;

  static Color pointAFor(Brightness brightness) =>
      brightness == Brightness.dark ? pointAOnDark : pointA;

  static Color pointBFor(Brightness brightness) =>
      brightness == Brightness.dark ? pointBOnDark : pointB;

  static Color accentWarningFor(Brightness brightness) =>
      brightness == Brightness.dark ? accentWarningOnDark : accentWarning;
}
