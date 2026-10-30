import 'package:flutter/material.dart';
import 'package:map/services/settings_service.dart';
import 'package:map/views/harita_ekran.dart';

void main() async {
  // Flutter binding başlatılması (Asenkron servisler için zorunlu)
  WidgetsFlutterBinding.ensureInitialized();

  // Yerel Ayarlar Servisi başlatma
  await SettingsService().init();

  // Not: SQLite harita önbelleği MapViewModel.init() içinde başlatılır.

  runApp(const KonumTakipApp());
}

class KonumTakipApp extends StatelessWidget {
  const KonumTakipApp({super.key});

  /// Marka rengi: göl mavisi (blue.shade800). DESIGN.md ile belgelenmiştir.
  static const Color _seedColor = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final settingsService = SettingsService();
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: settingsService.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Göl Sepet Takip',
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
      seedColor: _seedColor,
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
