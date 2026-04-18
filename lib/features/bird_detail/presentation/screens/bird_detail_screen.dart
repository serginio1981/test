import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../identification/domain/entities/identified_bird.dart';
import '../providers/bird_detail_provider.dart';
import '../widgets/bird_image_carousel.dart';
import '../widgets/sightings_map.dart';

class BirdDetailScreen extends ConsumerStatefulWidget {
  const BirdDetailScreen({
    super.key,
    required this.bird,
    this.userLat,
    this.userLng,
  });

  final IdentifiedBird bird;
  final double? userLat;
  final double? userLng;

  @override
  ConsumerState<BirdDetailScreen> createState() => _BirdDetailScreenState();
}

class _BirdDetailScreenState extends ConsumerState<BirdDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(birdDetailProvider(widget.bird));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: detailAsync.when(
                loading: () => Container(color: AppColors.primary.withOpacity(0.2)),
                error: (_, __) => Container(color: AppColors.primary.withOpacity(0.1)),
                data: (detail) => BirdImageCarousel(
                  imageUrls: detail.imageUrls,
                  thumbnailUrl: detail.thumbnailUrl,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => Share.share(
                  'Check out the ${widget.bird.commonName} (${widget.bird.scientificName})!',
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.bird.commonName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.bird.scientificName,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      _ConfidenceBadge(confidence: widget.bird.confidence),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(text: 'INFO'),
                      Tab(text: 'SIGHTINGS'),
                      Tab(text: 'MAP'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _InfoTab(bird: widget.bird),
                _SightingsTab(bird: widget.bird),
                _MapTab(
                  bird: widget.bird,
                  userLat: widget.userLat,
                  userLng: widget.userLng,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(
        '${(confidence * 100).toStringAsFixed(0)}% match',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.bird});
  final IdentifiedBird bird;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(birdDetailProvider(bird));

    return detailAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (detail) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (detail.description != null) ...[
            Text(
              detail.description!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 16),
          ] else
            const Text(
              'No description available.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          if (detail.wikipediaUrl != null)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Read more on Wikipedia'),
              onPressed: () => launchUrl(Uri.parse(detail.wikipediaUrl!)),
            ),
        ],
      ),
    );
  }
}

class _SightingsTab extends ConsumerWidget {
  const _SightingsTab({required this.bird});
  final IdentifiedBird bird;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = bird.eBirdCode ?? _guesseBirdCode(bird.scientificName);
    final sightingsAsync = ref.watch(
      birdSightingsProvider(
        SightingsParams(speciesCode: code, lat: 40.7128, lng: -74.0060),
      ),
    );

    return sightingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, color: AppColors.textHint, size: 48),
              const SizedBox(height: 12),
              Text(e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
      data: (sightings) => sightings.isEmpty
          ? const Center(
              child: Text(
                'No recent sightings found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: sightings.length,
              itemBuilder: (context, i) {
                final s = sightings[i];
                return ListTile(
                  leading: const Icon(Icons.location_on,
                      color: AppColors.primary),
                  title: Text(s.locationName),
                  subtitle: Text(
                    '${s.observedAt.year}-${s.observedAt.month.toString().padLeft(2, '0')}-${s.observedAt.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: s.howMany != null
                      ? Text('×${s.howMany}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold))
                      : null,
                );
              },
            ),
    );
  }

  String _guesseBirdCode(String scientificName) {
    final parts = scientificName.toLowerCase().split(' ');
    if (parts.length >= 2) {
      return '${parts[0].substring(0, 3)}${parts[1].substring(0, 3)}';
    }
    return scientificName.toLowerCase().replaceAll(' ', '').substring(0, 6);
  }
}

class _MapTab extends ConsumerWidget {
  const _MapTab({
    required this.bird,
    this.userLat,
    this.userLng,
  });

  final IdentifiedBird bird;
  final double? userLat;
  final double? userLng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = bird.eBirdCode ?? _guesseBirdCode(bird.scientificName);
    final lat = userLat ?? 40.7128;
    final lng = userLng ?? -74.0060;

    final sightingsAsync = ref.watch(
      birdSightingsProvider(
        SightingsParams(speciesCode: code, lat: lat, lng: lng),
      ),
    );

    return sightingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          SightingsMap(sightings: const [], userLat: lat, userLng: lng),
      data: (sightings) =>
          SightingsMap(sightings: sightings, userLat: lat, userLng: lng),
    );
  }

  String _guesseBirdCode(String scientificName) {
    final parts = scientificName.toLowerCase().split(' ');
    if (parts.length >= 2) {
      return '${parts[0].substring(0, 3)}${parts[1].substring(0, 3)}';
    }
    return scientificName.toLowerCase().replaceAll(' ', '').substring(0, 6);
  }
}
