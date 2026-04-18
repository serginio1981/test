import '../../domain/entities/identified_bird.dart';

class BirdNetDetection {
  const BirdNetDetection({
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    this.startTime,
    this.endTime,
  });

  final String commonName;
  final String scientificName;
  final double confidence;
  final double? startTime;
  final double? endTime;

  factory BirdNetDetection.fromJson(Map<String, dynamic> json) {
    return BirdNetDetection(
      commonName: json['common_name'] as String? ?? 'Unknown',
      scientificName: json['scientific_name'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      startTime: (json['start_time'] as num?)?.toDouble(),
      endTime: (json['end_time'] as num?)?.toDouble(),
    );
  }

  IdentifiedBird toEntity() => IdentifiedBird(
        commonName: commonName,
        scientificName: scientificName,
        confidence: confidence,
      );
}
