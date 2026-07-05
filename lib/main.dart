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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Göl Sepet Takip',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade800,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),
      ),
      home: const HaritaEkran(),
    );
  }
}
