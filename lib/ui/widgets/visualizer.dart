import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/m_theme.dart';

/// Lightweight equalizer-style animation driven by playback state only.
/// It does not claim to analyse the actual audio spectrum.
class Visualizer extends StatefulWidget {
  const Visualizer({
    super.key,
    required this.playing,
    this.bars = 28,
    this.height = 34,
    this.active = true,
  });

  final bool playing;
  final int bars;
  final double height;
  final bool active;

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant Visualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.playing && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = math.max(3, widget.bars);
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List<Widget>.generate(count, (i) {
              final phase = i * 0.47;
              final wave = (math.sin(_c.value * math.pi * 2 + phase) + 1) / 2;
              final base = widget.playing ? 0.22 + wave * 0.78 : 0.12;
              final h = widget.height * base;
              return Container(
                width: 2.2,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      MColors.darkRed,
                      widget.active ? MColors.primary : MColors.muted,
                      widget.active ? MColors.bright : MColors.muted,
                    ],
                  ),
                  boxShadow: widget.active && widget.playing
                      ? [BoxShadow(color: MColors.primary.withOpacity(0.35), blurRadius: 6)]
                      : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
