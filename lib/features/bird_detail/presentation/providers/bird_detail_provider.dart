import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/providers.dart';
import '../../../identification/domain/entities/identified_bird.dart';
import '../../domain/entities/bird_detail.dart';
import '../../domain/entities/bird_sighting.dart';

final birdDetailProvider =
    FutureProvider.family<BirdDetail, IdentifiedBird>((ref, bird) {
  final repo = ref.read(birdDetailRepositoryProvider);
  return repo.getBirdDetail(bird.commonName, bird.scientificName);
});

class SightingsParams {
  const SightingsParams({
    required this.speciesCode,
    required this.lat,
    required this.lng,
  });

  final String speciesCode;
  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is SightingsParams &&
      speciesCode == other.speciesCode &&
      lat == other.lat &&
      lng == other.lng;

  @override
  int get hashCode => Object.hash(speciesCode, lat, lng);
}

final birdSightingsProvider =
    FutureProvider.family<List<BirdSighting>, SightingsParams>(
        (ref, params) async {
  final repo = ref.read(birdDetailRepositoryProvider);
  return repo.getSightings(
    speciesCode: params.speciesCode,
    lat: params.lat,
    lng: params.lng,
  );
});
