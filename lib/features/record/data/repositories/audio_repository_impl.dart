import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../domain/entities/recording_session.dart';
import '../../domain/repositories/audio_repository.dart';
import '../datasources/audio_recorder_datasource.dart';

class AudioRepositoryImpl implements AudioRepository {
  AudioRepositoryImpl(this._datasource);

  final AudioRecorderDatasource _datasource;

  @override
  Stream<double> get amplitudeStream => _datasource.amplitudeStream;

  @override
  bool get isRecording => false;

  @override
  Future<bool> checkPermission() => _datasource.hasPermission();

  @override
  Future<bool> requestPermission() => _datasource.hasPermission();

  @override
  Future<void> startRecording() => _datasource.start();

  @override
  Future<RecordingSession> stopRecording() async {
    final (path, startedAt, duration) = await _datasource.stop();

    double? lat;
    double? lon;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      lat = pos.latitude;
      lon = pos.longitude;
    } catch (_) {
      // Location is optional — silently ignore
    }

    return RecordingSession(
      filePath: path,
      startedAt: startedAt,
      duration: duration,
      latitude: lat,
      longitude: lon,
    );
  }
}
