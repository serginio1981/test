import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/history_entry.dart';

part 'history_entry_model.g.dart';

@HiveType(typeId: 0)
class HistoryEntryModel extends HiveObject {
  HistoryEntryModel({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.recordedAt,
    required this.confidence,
    this.audioFilePath,
    this.latitude,
    this.longitude,
    this.thumbnailUrl,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String commonName;

  @HiveField(2)
  String scientificName;

  @HiveField(3)
  DateTime recordedAt;

  @HiveField(4)
  double confidence;

  @HiveField(5)
  String? audioFilePath;

  @HiveField(6)
  double? latitude;

  @HiveField(7)
  double? longitude;

  @HiveField(8)
  String? thumbnailUrl;

  HistoryEntry toEntity() => HistoryEntry(
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

  factory HistoryEntryModel.fromEntity(HistoryEntry e) => HistoryEntryModel(
        id: e.id,
        commonName: e.commonName,
        scientificName: e.scientificName,
        recordedAt: e.recordedAt,
        confidence: e.confidence,
        audioFilePath: e.audioFilePath,
        latitude: e.latitude,
        longitude: e.longitude,
        thumbnailUrl: e.thumbnailUrl,
      );
}
