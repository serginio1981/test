import '../../../../core/storage/secure_storage_service.dart';
import '../../../record/domain/entities/recording_session.dart';
import '../../domain/entities/identified_bird.dart';
import '../../domain/repositories/identification_repository.dart';
import '../datasources/birdnet_remote_datasource.dart';

class IdentificationRepositoryImpl implements IdentificationRepository {
  IdentificationRepositoryImpl(this._datasource);

  final BirdNetRemoteDatasource _datasource;

  @override
  Future<List<IdentifiedBird>> identify(RecordingSession session) async {
    final minConf = await SecureStorageService.getMinConfidence();

    final detections = await _datasource.analyze(
      session,
      minConfidence: minConf,
    );

    // Deduplicate: keep highest confidence per species
    final map = <String, IdentifiedBird>{};
    for (final d in detections) {
      final entity = d.toEntity();
      final existing = map[entity.scientificName];
      if (existing == null || entity.confidence > existing.confidence) {
        map[entity.scientificName] = entity;
      }
    }

    final results = map.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return results;
  }
}
