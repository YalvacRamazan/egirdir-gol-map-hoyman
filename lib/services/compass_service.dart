import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';

/// Cihaz pusulası (manyetometre) servisi.
///
/// Cihazın baktığı yönü (heading) derece cinsinden yayınlar:
/// 0° = kuzey, saat yönü pozitif. GPS `Position.heading`'i hareket
/// yönü verdiği için baktığı yön için bu servis kullanılır.
///
/// Sensör yok / izinsiz / akış hatası durumlarında exception fırlatmaz;
/// [isAvailable] üzerinden durum bildirilir. İlk olay belirli süre
/// içinde gelmezse sensör kullanılamıyor kabul edilir.
class CompassService {
  /// Süre: ilk pusula olayı bu süre içinde gelmezse sensör yok sayılır.
  static const Duration _firstEventTimeout = Duration(seconds: 3);

  final ValueNotifier<bool> _isAvailable = ValueNotifier<bool>(false);
  bool _isStarted = false;
  bool _isDisposed = false;
  StreamSubscription<CompassEvent>? _subscription;
  Timer? _firstEventTimer;

  /// Cihazın baktığı yön (derece, 0=K, saat yönü). Yalnızca sensör
  /// kullanılabilirken olay yayınlar.
  Stream<double> get headings => _headingController.stream;
  final StreamController<double> _headingController =
      StreamController<double>.broadcast();

  /// Sensör kullanılabilirlik durumu (UI'da ValueListenableBuilder ile dinlenir).
  ValueNotifier<bool> get isAvailable => _isAvailable;

  /// Pusula akışını başlatır. Tekrarlı çağrı güvenli (idempotent).
  void start() {
    if (_isDisposed || _isStarted) return;
    _isStarted = true;

    try {
      // flutter_compass: sensör yoksa events null döner (exception değil).
      final Stream<CompassEvent>? events = FlutterCompass.events;
      if (events == null) {
        _isAvailable.value = false;
        _isStarted = false;
        return;
      }

      // İlk olay gelmezse (ör. sensör var ama veri üretmiyor) kullanılamaz say.
      _firstEventTimer = Timer(_firstEventTimeout, () {
        if (!_isAvailable.value && !_isDisposed) {
          _isAvailable.value = false;
          _isStarted = false;
        }
      });

      _subscription = events.listen(
        (CompassEvent event) {
          if (_isDisposed) return;
          final double? heading = event.heading;
          if (heading == null || heading.isNaN) return;

          _firstEventTimer?.cancel();
          _isAvailable.value = true;
          if (!_headingController.isClosed) {
            _headingController.add(heading);
          }
        },
        onError: (Object error) {
          // Akış hatası: uygulamayı düşürme, durumu bildir.
          debugPrint('CompassService akış hatası: $error');
          _firstEventTimer?.cancel();
          _isAvailable.value = false;
          _isStarted = false;
        },
        cancelOnError: true,
      );
    } catch (e) {
      // Platform kanalı kurulamazsa (ör. desteklenmeyen platform) sessizce devre dışı.
      debugPrint('CompassService başlatılamadı: $e');
      _firstEventTimer?.cancel();
      _isAvailable.value = false;
      _isStarted = false;
    }
  }

  /// Pusula akışını durdurur (pil tasarrufu). Tekrarlı çağrı güvenli.
  void stop() {
    if (_isDisposed) return;
    _firstEventTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _isStarted = false;
    _isAvailable.value = false;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _firstEventTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _headingController.close();
    _isAvailable.dispose();
  }
}
