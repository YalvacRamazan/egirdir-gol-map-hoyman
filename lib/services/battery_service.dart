import 'package:battery_plus/battery_plus.dart';

class BatteryService {
  static final BatteryService _instance = BatteryService._internal();
  factory BatteryService() => _instance;
  BatteryService._internal();

  final Battery _battery = Battery();

  /// Pil yüzdesini döner; okunamazsa null döner.
  Future<int?> level() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  /// Pil politikası: seviye biliniyor ve %50'nin üstündeyse boost,
  /// okunamıyorsa doğruluk lehine boost seçilir.
  Future<bool> shouldUseBoost() async {
    return shouldUseBoostFromLevel(await level());
  }

  /// Plugin'e bağımsız saf politika: %50 üstü boost, altı tasarruf;
  /// seviye okunamıyorsa doğruluk lehine boost seçilir.
  static bool shouldUseBoostFromLevel(int? level) =>
      level == null || level > 50;
}
