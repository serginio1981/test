import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/ebird_sighting_model.dart';

class EBirdSightingsDatasource {
  Future<List<EBirdSightingModel>> getRecentSightings({
    required String speciesCode,
    required double lat,
    required double lng,
  }) async {
    final apiKey = await SecureStorageService.getEBirdApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const ApiException('eBird API key not configured', statusCode: 401);
    }

    updateEBirdToken(apiKey);

    try {
      final response = await eBirdDio.get(
        '/data/obs/geo/recent',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'dist': AppConstants.eBirdRadiusKm,
          'species': speciesCode,
          'maxResults': 100,
          'back': AppConstants.eBirdDaysBack,
          'fmt': 'json',
        },
      );

      if (response.data is List) {
        return (response.data as List)
            .map((e) =>
                EBirdSightingModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw DioClient.mapToAppException(e);
    }
  }

  Future<List<EBirdSightingModel>> getRegionalSightings({
    required String speciesCode,
    required String regionCode,
  }) async {
    final apiKey = await SecureStorageService.getEBirdApiKey();
    if (apiKey == null || apiKey.isEmpty) return [];
    updateEBirdToken(apiKey);

    try {
      final response = await eBirdDio.get(
        '/data/obs/$regionCode/recent/$speciesCode',
        queryParameters: {'maxResults': 50, 'back': AppConstants.eBirdDaysBack},
      );

      if (response.data is List) {
        return (response.data as List)
            .map((e) =>
                EBirdSightingModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (_) {
      return [];
    }
  }
}
