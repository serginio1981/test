import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class ApiConstants {
  static String get birdNetBaseUrl =>
      dotenv.env['BIRDNET_BASE_URL'] ?? 'https://birdnet.cornell.edu/api/v1';
  static const String birdNetAnalyze = '/analyze';

  static const String eBirdBaseUrl = 'https://api.ebird.org/v2';
  static const String eBirdRecentGeoObs = '/data/obs/geo/recent';

  static const String wikipediaBaseUrl = 'https://en.wikipedia.org/api/rest_v1';
  static const String wikipediaSummary = '/page/summary/';

  static const String iNatBaseUrl = 'https://api.inaturalist.org/v1';
  static const String iNatObservations = '/observations';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
}
