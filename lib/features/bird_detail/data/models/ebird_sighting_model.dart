import '../../domain/entities/bird_sighting.dart';

class EBirdSightingModel {
  const EBirdSightingModel({
    required this.lat,
    required this.lng,
    required this.locName,
    required this.obsDt,
    this.howMany,
    this.userDisplayName,
  });

  final double lat;
  final double lng;
  final String locName;
  final String obsDt;
  final int? howMany;
  final String? userDisplayName;

  factory EBirdSightingModel.fromJson(Map<String, dynamic> json) {
    return EBirdSightingModel(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      locName: json['locName'] as String? ?? '',
      obsDt: json['obsDt'] as String? ?? '',
      howMany: json['howMany'] as int?,
      userDisplayName: json['userDisplayName'] as String?,
    );
  }

  BirdSighting toEntity() {
    DateTime observedAt;
    try {
      observedAt = DateTime.parse(obsDt.replaceFirst(' ', 'T'));
    } catch (_) {
      observedAt = DateTime.now();
    }
    return BirdSighting(
      latitude: lat,
      longitude: lng,
      locationName: locName,
      observedAt: observedAt,
      howMany: howMany,
      observerName: userDisplayName,
    );
  }
}
