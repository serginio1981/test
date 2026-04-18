import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/hive_service.dart';
import '../../domain/entities/history_entry.dart';
import '../models/history_entry_model.dart';

class HistoryLocalDatasource {
  static const _uuid = Uuid();

  List<HistoryEntry> getAll() {
    final box = HiveService.historyBox;
    final entries = box.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return entries.map((m) => m.toEntity()).toList();
  }

  Future<void> save({
    required String commonName,
    required String scientificName,
    required double confidence,
    required DateTime recordedAt,
    String? audioFilePath,
    double? latitude,
    double? longitude,
    String? thumbnailUrl,
  }) async {
    final box = HiveService.historyBox;

    // Trim old entries if over limit
    if (box.length >= AppConstants.maxHistoryEntries) {
      final oldest = box.values.reduce(
          (a, b) => a.recordedAt.isBefore(b.recordedAt) ? a : b);
      await oldest.delete();
    }

    final id = _uuid.v4();
    final model = HistoryEntryModel(
      id: id,
      commonName: commonName,
      scientificName: scientificName,
      recordedAt: recordedAt,
      confidence: confidence,
      audioFilePath: audioFilePath,
      latitude: latitude,
      longitude: longitude,
      thumbnailUrl: thumbnailUrl,
    );
    await box.put(id, model);
  }

  Future<void> delete(String id) async {
    await HiveService.historyBox.delete(id);
  }

  Future<void> clearAll() async {
    await HiveService.historyBox.clear();
  }
}
