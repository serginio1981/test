import '../../../history/data/datasources/history_local_datasource.dart';

class SaveIdentificationUsecase {
  const SaveIdentificationUsecase(this._datasource);

  final HistoryLocalDatasource _datasource;

  Future<void> execute({
    required String commonName,
    required String scientificName,
    required double confidence,
    required DateTime recordedAt,
    String? audioFilePath,
    double? latitude,
    double? longitude,
    String? thumbnailUrl,
  }) {
    return _datasource.save(
      commonName: commonName,
      scientificName: scientificName,
      confidence: confidence,
      recordedAt: recordedAt,
      audioFilePath: audioFilePath,
      latitude: latitude,
      longitude: longitude,
      thumbnailUrl: thumbnailUrl,
    );
  }
}
