import 'dart:io';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../record/domain/entities/recording_session.dart';
import '../models/birdnet_response_model.dart';

class BirdNetRemoteDatasource {
  BirdNetRemoteDatasource();

  Future<List<BirdNetDetection>> analyze(
    RecordingSession session, {
    double sensitivity = 1.0,
    double minConfidence = 0.1,
  }) async {
    final file = File(session.filePath);
    if (!file.existsSync()) {
      throw const AudioRecordingException('Recording file not found');
    }

    final today = DateFormat('yyyy-MM-dd').format(session.startedAt);

    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        session.filePath,
        filename: 'recording.wav',
      ),
      'sensitivity': sensitivity.toString(),
      'min_conf': minConfidence.toString(),
      'date': today,
      if (session.latitude != null) 'lat': session.latitude.toString(),
      if (session.longitude != null) 'lon': session.longitude.toString(),
    });

    try {
      final response = await birdNetDio.post(
        ApiConstants.birdNetAnalyze,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      if (response.data is List) {
        final list = response.data as List;
        return list
            .map((e) => BirdNetDetection.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw const IdentificationException('Unexpected response format');
    } on DioException catch (e) {
      throw DioClient.mapToAppException(e);
    }
  }
}
