class RecordingSession {
  const RecordingSession({
    required this.filePath,
    required this.startedAt,
    required this.duration,
    this.latitude,
    this.longitude,
  });

  final String filePath;
  final DateTime startedAt;
  final Duration duration;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingSession &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath;

  @override
  int get hashCode => filePath.hashCode;
}
