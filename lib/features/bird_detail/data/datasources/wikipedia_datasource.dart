import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../models/wikipedia_summary_model.dart';

class WikipediaDatasource {
  Future<WikipediaSummaryModel?> getSummary(String scientificName) async {
    final title = Uri.encodeComponent(
      scientificName.trim().replaceAll(' ', '_'),
    );

    try {
      final response = await wikipediaDio.get('/page/summary/$title');
      return WikipediaSummaryModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw DioClient.mapToAppException(e);
    }
  }
}
