import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderDatasource {
  AudioRecorderDatasource() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  final _amplitudeController = StreamController<double>.broadcast();
  Timer? _amplitudeTimer;
  String? _currentPath;
  DateTime? _startTime;

  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final filename =
        'bird_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
    _currentPath = p.join(dir.path, filename);
    _startTime = DateTime.now();

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 48000,
        numChannels: 1,
      ),
      path: _currentPath!,
    );

    _amplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        if (await _recorder.isRecording()) {
          final amp = await _recorder.getAmplitude();
          _amplitudeController.add(amp.current);
        }
      },
    );
  }

  Future<(String path, DateTime startedAt, Duration duration)> stop() async {
    _amplitudeTimer?.cancel();
    await _recorder.stop();
    final now = DateTime.now();
    final duration = now.difference(_startTime ?? now);
    final path = _currentPath!;
    _currentPath = null;
    _startTime = null;
    return (path, _startTime ?? now.subtract(duration), duration);
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Future<void> dispose() async {
    _amplitudeTimer?.cancel();
    await _amplitudeController.close();
    await _recorder.dispose();
  }
}
