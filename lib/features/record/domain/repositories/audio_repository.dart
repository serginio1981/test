import '../entities/recording_session.dart';

abstract class AudioRepository {
  Future<bool> checkPermission();
  Future<bool> requestPermission();
  Future<void> startRecording();
  Future<RecordingSession> stopRecording();
  Stream<double> get amplitudeStream;
  bool get isRecording;
}
