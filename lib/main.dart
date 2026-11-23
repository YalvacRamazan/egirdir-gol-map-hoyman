import 'package:flutter/material.dart';
import 'package:map/services/settings_service.dart';
import 'package:map/services/sqlite_tile_cache_service.dart';
import 'package:map/theme/palette.dart';
import 'package:map/views/harita_ekran.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SettingsService().init();
  await SqliteTileCacheService().init();

  runApp(const KonumTakipApp());
}

class KonumTakipApp extends StatelessWidget {
  const KonumTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = SettingsService();
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: settingsService.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Sepet Takip',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeMode,
          home: const HaritaEkran(),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.primary,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        centerTitle: true,
      ),
    );
  }
}
