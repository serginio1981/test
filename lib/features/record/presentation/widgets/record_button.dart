import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/recorder_provider.dart';

class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.state,
    required this.onTap,
  });

  final RecorderState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRecording = state.isRecording;
    final isProcessing = state.isProcessing;

    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? AppColors.recordingRed : AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? AppColors.recordingRed : AppColors.primary)
                  .withOpacity(0.4),
              blurRadius: isRecording ? 24 : 12,
              spreadRadius: isRecording ? 4 : 0,
            ),
          ],
        ),
        child: isProcessing
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Icon(
                isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 40,
              ),
      ),
    );
  }
}
