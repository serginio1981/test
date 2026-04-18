import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

import '../constants/api_constants.dart';
import '../errors/app_exception.dart';

final _log = Logger();

class DioClient {
  DioClient._();

  static Dio get birdNet => _birdNetInstance;
  static Dio get eBird => _eBirdInstance;
  static Dio get wikipedia => _wikipediaInstance;
  static Dio get iNat => _iNatInstance;

  static final Dio _birdNetInstance = _build(ApiConstants.birdNetBaseUrl);
  static final Dio _eBirdInstance = _build(ApiConstants.eBirdBaseUrl);
  static final Dio _wikipediaInstance = _build(ApiConstants.wikipediaBaseUrl);
  static final Dio _iNatInstance = _build(ApiConstants.iNatBaseUrl);

  static Dio _build(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          _log.e('Dio error: ${error.message}', error: error);
          handler.next(error);
        },
      ),
    );

    return dio;
  }

  static void updateEBirdToken(String token) {
    _eBirdInstance.options.headers['X-eBirdApiToken'] = token;
  }

  static DioException mapToDioException(DioException e) => e;

  static AppException mapToAppException(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkException();
    }
    final statusCode = e.response?.statusCode;
    final message = e.response?.data?['error'] ?? e.message ?? 'Unknown error';
    return ApiException(message.toString(), statusCode: statusCode);
  }
}

// Re-export for easy import
Dio get birdNetDio => DioClient.birdNet;
Dio get eBirdDio => DioClient.eBird;
Dio get wikipediaDio => DioClient.wikipedia;
Dio get iNatDio => DioClient.iNat;

void updateEBirdToken(String token) {
  DioClient.updateEBirdToken(token);
  _log.d('eBird token updated');
}
