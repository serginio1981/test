class HistoryEntry {
  const HistoryEntry({
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

  final String id;
  final String commonName;
  final String scientificName;
  final DateTime recordedAt;
  final double confidence;
  final String? audioFilePath;
  final double? latitude;
  final double? longitude;
  final String? thumbnailUrl;

  bool get hasLocation => latitude != null && longitude != null;

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';
}
