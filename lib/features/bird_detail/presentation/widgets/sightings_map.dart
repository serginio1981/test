import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/bird_sighting.dart';

class SightingsMap extends StatelessWidget {
  const SightingsMap({
    super.key,
    required this.sightings,
    this.userLat,
    this.userLng,
  });

  final List<BirdSighting> sightings;
  final double? userLat;
  final double? userLng;

  @override
  Widget build(BuildContext context) {
    if (sightings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: AppColors.textHint),
            SizedBox(height: 12),
            Text(
              'No sightings found nearby',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              'Configure your eBird API key in Settings',
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final center = sightings.isNotEmpty
        ? LatLng(sightings.first.latitude, sightings.first.longitude)
        : LatLng(userLat ?? 0, userLng ?? 0);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 7,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.birdid.bird_sound_identifier',
        ),
        MarkerLayer(
          markers: [
            ...sightings.map(
              (s) => Marker(
                point: LatLng(s.latitude, s.longitude),
                width: 32,
                height: 32,
                child: GestureDetector(
                  onTap: () => _showSightingInfo(context, s),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.flutter_dash,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
            if (userLat != null && userLng != null)
              Marker(
                point: LatLng(userLat!, userLng!),
                width: 32,
                height: 32,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child:
                      const Icon(Icons.my_location, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showSightingInfo(BuildContext context, BirdSighting s) {
    final date = DateFormat('MMM d, yyyy').format(s.observedAt);
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.locationName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Observed: $date',
                style: const TextStyle(color: AppColors.textSecondary)),
            if (s.howMany != null)
              Text('Count: ${s.howMany}',
                  style: const TextStyle(color: AppColors.textSecondary)),
            if (s.observerName != null)
              Text('Observer: ${s.observerName}',
                  style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
