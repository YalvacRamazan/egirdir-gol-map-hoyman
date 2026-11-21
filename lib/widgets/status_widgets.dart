import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map/utils/time_format.dart';

class LiveClockChip extends StatefulWidget {
  const LiveClockChip({super.key});

  @override
  State<LiveClockChip> createState() => _LiveClockChipState();
}

class _LiveClockChipState extends State<LiveClockChip> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleNextMinute();
  }

  void _scheduleNextMinute() {
    final now = DateTime.now();
    final delay = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
    _timer = Timer(
      delay.inMilliseconds <= 0 ? const Duration(seconds: 1) : delay,
      () {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
        _scheduleNextMinute();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = formatHourMinute(_now);
    return Semantics(
      label: 'Şu anki saat $text',
      child: StatusPill(
        icon: Icons.access_time,
        text: text,
        emphasized: true,
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool emphasized;

  const StatusPill({
    super.key,
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primary
            : scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: emphasized ? scheme.primary : scheme.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: emphasized ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: emphasized ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
