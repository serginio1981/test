import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/history_entry.dart';

class HistoryListItem extends StatelessWidget {
  const HistoryListItem({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          onTap: onTap,
          leading: _BirdThumbnail(url: entry.thumbnailUrl),
          title: Text(
            entry.commonName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.scientificName,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d, yyyy  HH:mm').format(entry.recordedAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                entry.confidencePercent,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (entry.hasLocation)
                const Icon(Icons.location_on, size: 12, color: AppColors.textHint),
            ],
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}

class _BirdThumbnail extends StatelessWidget {
  const _BirdThumbnail({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 52,
        height: 52,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.primary.withOpacity(0.1),
        child: const Icon(Icons.flutter_dash, color: AppColors.primary, size: 28),
      );
}
