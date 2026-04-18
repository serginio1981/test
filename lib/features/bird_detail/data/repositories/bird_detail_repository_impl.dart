import '../../domain/entities/bird_detail.dart';
import '../../domain/entities/bird_sighting.dart';
import '../datasources/ebird_sightings_datasource.dart';
import '../datasources/inaturalist_datasource.dart';
import '../datasources/wikipedia_datasource.dart';

class BirdDetailRepository {
  BirdDetailRepository({
    required WikipediaDatasource wikipedia,
    required INaturalistDatasource iNat,
    required EBirdSightingsDatasource eBird,
  })  : _wikipedia = wikipedia,
        _iNat = iNat,
        _eBird = eBird;

  final WikipediaDatasource _wikipedia;
  final INaturalistDatasource _iNat;
  final EBirdSightingsDatasource _eBird;

  Future<BirdDetail> getBirdDetail(
    String commonName,
    String scientificName,
  ) async {
    final results = await Future.wait([
      _wikipedia.getSummary(scientificName).catchError((_) => null),
      _iNat.getPhotos(scientificName).catchError((_) => <String>[]),
    ]);

    final summary = results[0];
    final photos = results[1] as List<String>;

    BirdDetail detail;
    if (summary != null) {
      detail = (summary as dynamic).toEntity(commonName, scientificName)
          as BirdDetail;
    } else {
      detail = BirdDetail(
        commonName: commonName,
        scientificName: scientificName,
      );
    }

    return detail.copyWith(imageUrls: photos);
  }

  Future<List<BirdSighting>> getSightings({
    required String speciesCode,
    required double lat,
    required double lng,
  }) async {
    try {
      final models = await _eBird.getRecentSightings(
        speciesCode: speciesCode,
        lat: lat,
        lng: lng,
      );
      return models.map((m) => m.toEntity()).toList();
    } catch (_) {
      return [];
    }
  }
}
