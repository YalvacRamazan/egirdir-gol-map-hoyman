import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppSettings {
  String backupPhoneNumber;
  double gpsAccuracyThreshold;
  String themeMode; // 'light' | 'dark' | 'system'

  AppSettings({
    this.backupPhoneNumber = '',
    this.gpsAccuracyThreshold = 15.0,
    this.themeMode = 'system',
  });

  Map<String, dynamic> toJson() => {
        'backupPhoneNumber': backupPhoneNumber,
        'gpsAccuracyThreshold': gpsAccuracyThreshold,
        'themeMode': themeMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      backupPhoneNumber: json['backupPhoneNumber'] as String? ?? '',
      gpsAccuracyThreshold: (json['gpsAccuracyThreshold'] as num?)?.toDouble() ?? 15.0,
      themeMode: json['themeMode'] as String? ?? 'system',
    );
  }
}

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;

  /// Tema modu değiştiğinde MaterialApp'i yeniden kurar.
  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  File? _settingsFile;

  Future<void> init() async {
    if (kIsWeb) {
      // Web için varsayılan ayarları kullan (bellek içi)
      _settings = AppSettings();
      themeModeNotifier.value = _parseThemeMode(_settings.themeMode);
      return;
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      _settingsFile = File(p.join(docDir.path, 'app_settings.json'));

      if (await _settingsFile!.exists()) {
        final content = await _settingsFile!.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(json);
      } else {
        await saveSettings(_settings);
      }
    } catch (e) {
      // Hata durumunda varsayılan ayarlarla devam et
    }
    themeModeNotifier.value = _parseThemeMode(_settings.themeMode);
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    _settings = newSettings;
    themeModeNotifier.value = _parseThemeMode(newSettings.themeMode);
    if (kIsWeb) return; // Web için bellekte güncellemek yeterli

    if (_settingsFile != null) {
      try {
        await _settingsFile!.writeAsString(jsonEncode(_settings.toJson()));
      } catch (e) {
        // Hata durumunu yoksay
      }
    }
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
