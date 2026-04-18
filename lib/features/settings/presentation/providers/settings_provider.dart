import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/app_settings.dart';

class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  SettingsNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final eBirdKey = await SecureStorageService.getEBirdApiKey() ?? '';
      final birdNetUrl = await SecureStorageService.getBirdNetUrl() ?? '';
      final minConf = await SecureStorageService.getMinConfidence();
      final duration = await SecureStorageService.getRecordingDuration();

      state = AsyncValue.data(AppSettings(
        eBirdApiKey: eBirdKey,
        birdNetBaseUrl: birdNetUrl,
        minConfidence: minConf,
        recordingDurationSeconds: duration,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setEBirdApiKey(String key) async {
    await SecureStorageService.setEBirdApiKey(key);
    _updateState((s) => s.copyWith(eBirdApiKey: key));
  }

  Future<void> setBirdNetUrl(String url) async {
    await SecureStorageService.setBirdNetUrl(url);
    _updateState((s) => s.copyWith(birdNetBaseUrl: url));
  }

  Future<void> setMinConfidence(double value) async {
    await SecureStorageService.setMinConfidence(value);
    _updateState((s) => s.copyWith(minConfidence: value));
  }

  Future<void> setRecordingDuration(int seconds) async {
    await SecureStorageService.setRecordingDuration(seconds);
    _updateState((s) => s.copyWith(recordingDurationSeconds: seconds));
  }

  void _updateState(AppSettings Function(AppSettings) updater) {
    state.whenData((current) {
      state = AsyncValue.data(updater(current));
    });
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>(
  (ref) => SettingsNotifier(),
);
