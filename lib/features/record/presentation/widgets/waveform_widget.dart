import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class WaveformWidget extends StatefulWidget {
  const WaveformWidget({
    super.key,
    required this.amplitude,
    required this.isActive,
  });

  final double amplitude;
  final bool isActive;

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _bars = List.filled(30, 0.05);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
  }

  @override
  void didUpdateWidget(WaveformWidget old) {
    super.didUpdateWidget(old);
    if (widget.isActive) {
      _bars[_index % _bars.length] = widget.amplitude.clamp(0.05, 1.0);
      _index++;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _WaveformPainter(
            bars: _bars,
            currentIndex: _index,
            isActive: widget.isActive,
            color: widget.isActive
                ? AppColors.recordingRed
                : AppColors.textHint,
          ),
          size: const Size(double.infinity, 60),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.currentIndex,
    required this.isActive,
    required this.color,
  });

  final List<double> bars;
  final int currentIndex;
  final bool isActive;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    final barWidth = size.width / bars.length;
    for (int i = 0; i < bars.length; i++) {
      final barIndex = (currentIndex - bars.length + i) % bars.length;
      final h = bars[barIndex.abs() % bars.length] * size.height;
      final x = i * barWidth + barWidth / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.currentIndex != currentIndex || old.isActive != isActive;
}
