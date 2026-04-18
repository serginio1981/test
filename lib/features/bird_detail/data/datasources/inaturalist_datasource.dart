import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/dio_client.dart';

class INaturalistDatasource {
  Future<List<String>> getPhotos(String scientificName,
      {int count = 8}) async {
    try {
      final response = await iNatDio.get(
        '/observations',
        queryParameters: {
          'taxon_name': scientificName,
          'quality_grade': 'research',
          'photos': true,
          'per_page': count,
          'order_by': 'votes',
          'order': 'desc',
        },
      );

      final results = response.data?['results'] as List? ?? [];
      final urls = <String>[];

      for (final obs in results) {
        final photos = obs['photos'] as List? ?? [];
        for (final photo in photos) {
          final url = photo['url'] as String?;
          if (url != null) {
            urls.add(url.replaceAll('square', 'medium'));
          }
        }
      }

      return urls;
    } on DioException catch (e) {
      throw DioClient.mapToAppException(e);
    }
  }
}
