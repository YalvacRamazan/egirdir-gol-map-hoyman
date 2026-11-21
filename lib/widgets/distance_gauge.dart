import 'package:flutter/material.dart';
import 'package:map/theme/palette.dart';

class DistanceGauge extends StatelessWidget {
  final double distanceMeters;
  final double maxRangeMeters;

  const DistanceGauge({
    super.key,
    required this.distanceMeters,
    this.maxRangeMeters = 500,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fillColor = Palette.primaryFor(scheme.brightness);
    final ratio = (distanceMeters / maxRangeMeters).clamp(0.0, 1.0);
    final fillHeightFactor = ratio < 0.04 ? 0.04 : ratio;

    return Semantics(
      label: 'Sepete uzaklık: ${distanceMeters.round()} metre',
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'UZAKLIK',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 18,
              height: 80,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: fillHeightFactor,
                        widthFactor: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: fillColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final f in const [0.25, 0.5, 0.75])
                    Positioned(
                      top: 80 * f - 0.5,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${distanceMeters.round()}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            Text(
              'metre',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
