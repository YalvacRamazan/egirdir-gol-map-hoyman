import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppSettings {
  String backupPhoneNumber;
  double gpsAccuracyThreshold;

  AppSettings({
    this.backupPhoneNumber = '',
    this.gpsAccuracyThreshold = 15.0,
  });

  Map<String, dynamic> toJson() => {
        'backupPhoneNumber': backupPhoneNumber,
        'gpsAccuracyThreshold': gpsAccuracyThreshold,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      backupPhoneNumber: json['backupPhoneNumber'] as String? ?? '',
      gpsAccuracyThreshold: (json['gpsAccuracyThreshold'] as num?)?.toDouble() ?? 15.0,
    );
  }
}

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;

  File? _settingsFile;

  Future<void> init() async {
    if (kIsWeb) {
      // Web için varsayılan ayarları kullan (bellek içi)
      _settings = AppSettings();
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
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    _settings = newSettings;
    if (kIsWeb) return; // Web için bellekte güncellemek yeterli

    if (_settingsFile != null) {
      try {
        await _settingsFile!.writeAsString(jsonEncode(_settings.toJson()));
      } catch (e) {
        // Hata durumunu yoksay
      }
    }
  }
}
