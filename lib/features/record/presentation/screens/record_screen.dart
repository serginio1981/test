import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/recorder_provider.dart';
import '../widgets/record_button.dart';
import '../widgets/waveform_widget.dart';

class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recorderProvider);
    final notifier = ref.read(recorderProvider.notifier);

    // Navigate to results when a session is ready
    ref.listen<RecorderState>(recorderProvider, (prev, next) {
      if (next.session != null &&
          prev?.session == null &&
          next.status == RecorderStatus.idle) {
        context.push('/results', extra: next.session);
        notifier.reset();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bird Sound Identifier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              _BirdAnimation(isRecording: state.isRecording),
              const SizedBox(height: 32),
              _StatusText(state: state),
              const SizedBox(height: 24),
              WaveformWidget(
                amplitude: state.amplitude,
                isActive: state.isRecording,
              ),
              const SizedBox(height: 32),
              if (state.isRecording)
                _ElapsedTimer(elapsed: state.elapsed),
              const SizedBox(height: 16),
              RecordButton(
                state: state,
                onTap: state.isRecording
                    ? notifier.stopRecording
                    : notifier.startRecording,
              ),
              const SizedBox(height: 16),
              _TipText(isRecording: state.isRecording),
              if (state.status == RecorderStatus.error)
                _ErrorBanner(message: state.errorMessage ?? 'Unknown error'),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirdAnimation extends StatelessWidget {
  const _BirdAnimation({required this.isRecording});
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isRecording ? AppColors.recordingRed : AppColors.primary)
            .withOpacity(0.1),
      ),
      child: Icon(
        Icons.flutter_dash,
        size: 72,
        color: isRecording ? AppColors.recordingRed : AppColors.primary,
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.state});
  final RecorderState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (state.status) {
      RecorderStatus.idle => 'Tap to identify a bird song',
      RecorderStatus.requestingPermission => 'Requesting microphone access...',
      RecorderStatus.recording => 'Listening...',
      RecorderStatus.processing => 'Analyzing sound...',
      RecorderStatus.error => 'Something went wrong',
    };

    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _ElapsedTimer extends StatelessWidget {
  const _ElapsedTimer({required this.elapsed});
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.recordingRed,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}

class _TipText extends StatelessWidget {
  const _TipText({required this.isRecording});
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return Text(
      isRecording
          ? 'Hold still — point toward the bird'
          : 'Works best in quiet environments',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textHint,
          ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
