import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyEBirdApiKey = 'ebird_api_key';
  static const _keyBirdNetUrl = 'birdnet_base_url';
  static const _keyMinConfidence = 'min_confidence';
  static const _keyRecordingDuration = 'recording_duration';

  static Future<String?> getEBirdApiKey() =>
      _storage.read(key: _keyEBirdApiKey);

  static Future<void> setEBirdApiKey(String key) =>
      _storage.write(key: _keyEBirdApiKey, value: key);

  static Future<String?> getBirdNetUrl() =>
      _storage.read(key: _keyBirdNetUrl);

  static Future<void> setBirdNetUrl(String url) =>
      _storage.write(key: _keyBirdNetUrl, value: url);

  static Future<double> getMinConfidence() async {
    final val = await _storage.read(key: _keyMinConfidence);
    return double.tryParse(val ?? '') ?? 0.1;
  }

  static Future<void> setMinConfidence(double value) =>
      _storage.write(key: _keyMinConfidence, value: value.toString());

  static Future<int> getRecordingDuration() async {
    final val = await _storage.read(key: _keyRecordingDuration);
    return int.tryParse(val ?? '') ?? 10;
  }

  static Future<void> setRecordingDuration(int seconds) =>
      _storage.write(key: _keyRecordingDuration, value: seconds.toString());
}
