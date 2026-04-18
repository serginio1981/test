class IdentifiedBird {
  const IdentifiedBird({
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    this.eBirdCode,
  });

  final String commonName;
  final String scientificName;
  final double confidence;
  final String? eBirdCode;

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';

  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.75) return ConfidenceLevel.high;
    if (confidence >= 0.5) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentifiedBird &&
          runtimeType == other.runtimeType &&
          scientificName == other.scientificName;

  @override
  int get hashCode => scientificName.hashCode;
}

enum ConfidenceLevel { high, medium, low }
