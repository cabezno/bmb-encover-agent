import 'dart:math';
import 'package:flutter/material.dart';

class VoiceLevelMeter extends StatelessWidget {
  final double level;

  const VoiceLevelMeter({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(21, (index) {
          final barCenter = index / 20.0;
          final distance = (barCenter - 0.5).abs() * 2;
          final barHeight = _calculateBarHeight(index);

          // Apply level influence
          final animatedHeight = barHeight * (0.3 + (level * 0.7));

          // Color gradient based on level
          final hue = 270.0 - (level * 180.0); // Purple to green
          final color = HSLColor.fromAHSL(
            0.7,
            hue.clamp(120.0, 270.0),
            0.8,
            0.5,
          ).toColor();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedContainer(
              duration: Duration(milliseconds: (50 + (distance * 80)).toInt()),
              width: 4,
              height: animatedHeight.clamp(4.0, 36.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  double _calculateBarHeight(int index) {
    final center = (index - 10).abs();
    // Gaussian-ish curve
    final raw = exp(-(center * center) / 20.0);
    return raw * 28.0 + 6.0;
  }
}
