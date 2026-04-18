import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/identified_bird.dart';
import 'confidence_bar.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.bird,
    required this.rank,
  });

  final IdentifiedBird bird;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/bird/${_encodeSpecies(bird)}', extra: bird),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RankBadge(rank: rank),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bird.commonName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          bird.scientificName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        bird.confidencePercent,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _confidenceColor(bird.confidenceLevel),
                        ),
                      ),
                      Text(
                        'confidence',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ConfidenceBar(confidence: bird.confidence),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'View details →',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _encodeSpecies(IdentifiedBird bird) =>
      Uri.encodeComponent(bird.scientificName.replaceAll(' ', '_'));

  Color _confidenceColor(ConfidenceLevel level) => switch (level) {
        ConfidenceLevel.high => AppColors.confidenceHigh,
        ConfidenceLevel.medium => AppColors.confidenceMedium,
        ConfidenceLevel.low => AppColors.confidenceLow,
      };
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: rank == 1 ? AppColors.accent : AppColors.primary.withOpacity(0.1),
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: rank == 1 ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
