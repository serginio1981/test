import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/providers.dart';
import '../../domain/entities/recording_session.dart';

enum RecorderStatus { idle, requestingPermission, recording, processing, error }

class RecorderState {
  const RecorderState({
    this.status = RecorderStatus.idle,
    this.elapsed = Duration.zero,
    this.amplitude = 0.0,
    this.errorMessage,
    this.session,
  });

  final RecorderStatus status;
  final Duration elapsed;
  final double amplitude;
  final String? errorMessage;
  final RecordingSession? session;

  bool get isRecording => status == RecorderStatus.recording;
  bool get isProcessing => status == RecorderStatus.processing;
  bool get isIdle => status == RecorderStatus.idle;

  RecorderState copyWith({
    RecorderStatus? status,
    Duration? elapsed,
    double? amplitude,
    String? errorMessage,
    RecordingSession? session,
  }) {
    return RecorderState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      amplitude: amplitude ?? this.amplitude,
      errorMessage: errorMessage ?? this.errorMessage,
      session: session ?? this.session,
    );
  }
}

class RecorderNotifier extends StateNotifier<RecorderState> {
  RecorderNotifier(this._ref) : super(const RecorderState());

  final Ref _ref;
  Timer? _elapsedTimer;
  StreamSubscription<double>? _ampSub;

  Future<void> startRecording() async {
    state = state.copyWith(status: RecorderStatus.requestingPermission);

    final repo = _ref.read(audioRepositoryProvider);
    final hasPermission = await repo.checkPermission();

    if (!hasPermission) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Microphone permission denied',
      );
      return;
    }

    try {
      await repo.startRecording();
      state = state.copyWith(
        status: RecorderStatus.recording,
        elapsed: Duration.zero,
      );

      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        state = state.copyWith(
          elapsed: state.elapsed + const Duration(seconds: 1),
        );
      });

      _ampSub = repo.amplitudeStream.listen((amp) {
        final normalized = ((amp + 60) / 60).clamp(0.0, 1.0);
        state = state.copyWith(amplitude: normalized);
      });
    } catch (e) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  Future<void> stopRecording() async {
    _elapsedTimer?.cancel();
    await _ampSub?.cancel();

    state = state.copyWith(status: RecorderStatus.processing);

    try {
      final repo = _ref.read(audioRepositoryProvider);
      final session = await repo.stopRecording();
      state = state.copyWith(
        status: RecorderStatus.idle,
        session: session,
        amplitude: 0.0,
        elapsed: Duration.zero,
      );
    } catch (e) {
      state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: 'Failed to stop recording: $e',
      );
    }
  }

  void reset() {
    _elapsedTimer?.cancel();
    state = const RecorderState();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _ampSub?.cancel();
    super.dispose();
  }
}

final recorderProvider =
    StateNotifierProvider<RecorderNotifier, RecorderState>((ref) {
  return RecorderNotifier(ref);
});
