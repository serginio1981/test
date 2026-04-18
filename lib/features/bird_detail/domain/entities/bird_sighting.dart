class BirdSighting {
  const BirdSighting({
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.observedAt,
    this.howMany,
    this.observerName,
  });

  final double latitude;
  final double longitude;
  final String locationName;
  final DateTime observedAt;
  final int? howMany;
  final String? observerName;
}
