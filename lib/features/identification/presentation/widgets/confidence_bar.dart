import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/identified_bird.dart';

class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({super.key, required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final level = confidence >= 0.75
        ? ConfidenceLevel.high
        : confidence >= 0.5
            ? ConfidenceLevel.medium
            : ConfidenceLevel.low;

    final color = switch (level) {
      ConfidenceLevel.high => AppColors.confidenceHigh,
      ConfidenceLevel.medium => AppColors.confidenceMedium,
      ConfidenceLevel.low => AppColors.confidenceLow,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: confidence,
        backgroundColor: color.withOpacity(0.15),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 8,
      ),
    );
  }
}
