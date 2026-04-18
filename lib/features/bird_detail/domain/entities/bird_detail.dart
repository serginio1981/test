class BirdDetail {
  const BirdDetail({
    required this.commonName,
    required this.scientificName,
    this.description,
    this.thumbnailUrl,
    this.wikipediaUrl,
    this.imageUrls = const [],
  });

  final String commonName;
  final String scientificName;
  final String? description;
  final String? thumbnailUrl;
  final String? wikipediaUrl;
  final List<String> imageUrls;

  BirdDetail copyWith({
    String? description,
    String? thumbnailUrl,
    String? wikipediaUrl,
    List<String>? imageUrls,
  }) {
    return BirdDetail(
      commonName: commonName,
      scientificName: scientificName,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      wikipediaUrl: wikipediaUrl ?? this.wikipediaUrl,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }
}
