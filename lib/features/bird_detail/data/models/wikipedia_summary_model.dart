import '../../domain/entities/bird_detail.dart';

class WikipediaSummaryModel {
  const WikipediaSummaryModel({
    required this.title,
    required this.extract,
    this.thumbnailUrl,
    this.contentUrl,
  });

  final String title;
  final String extract;
  final String? thumbnailUrl;
  final String? contentUrl;

  factory WikipediaSummaryModel.fromJson(Map<String, dynamic> json) {
    final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
    final urls = json['content_urls'] as Map<String, dynamic>?;
    final desktop = urls?['desktop'] as Map<String, dynamic>?;

    return WikipediaSummaryModel(
      title: json['title'] as String? ?? '',
      extract: json['extract'] as String? ?? '',
      thumbnailUrl: thumbnail?['source'] as String?,
      contentUrl: desktop?['page'] as String?,
    );
  }

  BirdDetail toEntity(String commonName, String scientificName) => BirdDetail(
        commonName: commonName,
        scientificName: scientificName,
        description: extract,
        thumbnailUrl: thumbnailUrl,
        wikipediaUrl: contentUrl,
      );
}
