import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/history_provider.dart';
import '../widgets/history_list_item.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClearAll(context, ref),
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: entries.isEmpty
          ? const _EmptyHistory()
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.read(historyProvider.notifier).refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  return HistoryListItem(
                    entry: entry,
                    onTap: () => context.push(
                      '/bird/${Uri.encodeComponent(entry.scientificName.replaceAll(' ', '_'))}',
                      extra: _entryToIdentifiedBird(entry),
                    ),
                    onDelete: () =>
                        ref.read(historyProvider.notifier).delete(entry.id),
                  );
                },
              ),
            ),
    );
  }

  dynamic _entryToIdentifiedBird(dynamic entry) {
    // Converts HistoryEntry to IdentifiedBird for navigation
    // Using dynamic to avoid circular imports — router handles the cast
    return entry;
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content:
            const Text('Are you sure you want to delete all history entries?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(historyProvider.notifier).clearAll();
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 72, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'No identifications yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Go record a bird sound to get started!',
            style: TextStyle(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
