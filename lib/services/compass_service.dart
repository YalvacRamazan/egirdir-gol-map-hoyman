import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';

class CompassService {
  static const Duration _firstEventTimeout = Duration(seconds: 3);

  final ValueNotifier<bool> _isAvailable = ValueNotifier<bool>(false);
  bool _isStarted = false;
  bool _isDisposed = false;
  StreamSubscription<CompassEvent>? _subscription;
  Timer? _firstEventTimer;

  Stream<double> get headings => _headingController.stream;
  final StreamController<double> _headingController =
      StreamController<double>.broadcast();

  ValueNotifier<bool> get isAvailable => _isAvailable;

  void start() {
    if (_isDisposed || _isStarted) return;
    _isStarted = true;

    try {
      final Stream<CompassEvent>? events = FlutterCompass.events;
      if (events == null) {
        _isAvailable.value = false;
        _isStarted = false;
        return;
      }

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
          debugPrint('CompassService akış hatası: $error');
          _firstEventTimer?.cancel();
          _isAvailable.value = false;
          _isStarted = false;
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('CompassService başlatılamadı: $e');
      _firstEventTimer?.cancel();
      _isAvailable.value = false;
      _isStarted = false;
    }
  }

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
