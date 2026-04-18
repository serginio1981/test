import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/providers.dart';
import '../../../record/domain/entities/recording_session.dart';
import '../providers/identification_provider.dart';
import '../widgets/result_card.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.session});

  final RecordingSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identificationAsync = ref.watch(identificationProvider(session));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          identificationAsync.whenOrNull(
                data: (birds) => IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => _shareResults(birds.isNotEmpty
                      ? birds.first.commonName
                      : 'No birds identified'),
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: identificationAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (birds) => _ResultsView(session: session, birds: birds, ref: ref),
      ),
    );
  }

  void _shareResults(String topBird) {
    Share.share(
      'I just identified a $topBird using Bird Sound Identifier! 🐦',
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            'Analyzing bird sound...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Identification failed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsView extends ConsumerWidget {
  const _ResultsView({
    required this.session,
    required this.birds,
    required this.ref,
  });

  final RecordingSession session;
  final List<dynamic> birds;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr =
        DateFormat('MMM d, yyyy • HH:mm').format(session.startedAt);

    return Column(
      children: [
        _SessionInfoBar(session: session, dateStr: dateStr),
        Expanded(
          child: birds.isEmpty
              ? const _NoBirdsFound()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: birds.length,
                  itemBuilder: (context, i) => ResultCard(
                    bird: birds[i],
                    rank: i + 1,
                  ),
                ),
        ),
        if (birds.isNotEmpty) _ActionBar(session: session, birds: birds),
      ],
    );
  }
}

class _SessionInfoBar extends StatelessWidget {
  const _SessionInfoBar({required this.session, required this.dateStr});

  final RecordingSession session;
  final String dateStr;

  @override
  Widget build(BuildContext context) {
    final duration = session.duration.inSeconds;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.primary.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 14, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(
            '${duration}s  •  $dateStr',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          if (session.hasLocation) ...[
            const SizedBox(width: 8),
            const Icon(Icons.location_on, size: 14, color: AppColors.textHint),
            const SizedBox(width: 2),
            Text(
              '${session.latitude!.toStringAsFixed(2)}, ${session.longitude!.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoBirdsFound extends StatelessWidget {
  const _NoBirdsFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hearing_disabled,
              size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'No birds identified',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Try recording in a quieter environment\nor closer to the bird',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.session, required this.birds});

  final RecordingSession session;
  final List<dynamic> birds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
              onPressed: () => _save(context, ref),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.mic),
              label: const Text('Record Again'),
              onPressed: () => context.go('/record'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    if (birds.isEmpty) return;
    final topBird = birds.first;
    final usecase = ref.read(saveIdentificationUsecaseProvider);
    await usecase.execute(
      commonName: topBird.commonName,
      scientificName: topBird.scientificName,
      confidence: topBird.confidence,
      recordedAt: session.startedAt,
      audioFilePath: session.filePath,
      latitude: session.latitude,
      longitude: session.longitude,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to history')),
      );
    }
  }
}
