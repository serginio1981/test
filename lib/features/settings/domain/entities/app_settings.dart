class AppSettings {
  const AppSettings({
    this.eBirdApiKey = '',
    this.birdNetBaseUrl = '',
    this.minConfidence = 0.1,
    this.recordingDurationSeconds = 10,
  });

  final String eBirdApiKey;
  final String birdNetBaseUrl;
  final double minConfidence;
  final int recordingDurationSeconds;

  bool get hasEBirdKey => eBirdApiKey.isNotEmpty;
  bool get hasBirdNetUrl => birdNetBaseUrl.isNotEmpty;

  AppSettings copyWith({
    String? eBirdApiKey,
    String? birdNetBaseUrl,
    double? minConfidence,
    int? recordingDurationSeconds,
  }) {
    return AppSettings(
      eBirdApiKey: eBirdApiKey ?? this.eBirdApiKey,
      birdNetBaseUrl: birdNetBaseUrl ?? this.birdNetBaseUrl,
      minConfidence: minConfidence ?? this.minConfidence,
      recordingDurationSeconds:
          recordingDurationSeconds ?? this.recordingDurationSeconds,
    );
  }
}
