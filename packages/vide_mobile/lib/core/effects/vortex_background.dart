import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class VortexBackground extends StatefulWidget {
  final Widget child;

  const VortexBackground({super.key, required this.child});

  @override
  State<VortexBackground> createState() => _VortexBackgroundState();
}

class _VortexBackgroundState extends State<VortexBackground>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late AnimationController _controller;
  double _time = 0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);

    _loadShader();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset('shaders/vortex.frag');
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
    _startIfNeeded();
  }

  void _startIfNeeded() {
    if (_shader != null && !MediaQuery.disableAnimationsOf(context)) {
      _lastElapsed = _controller.lastElapsedDuration ?? Duration.zero;
      _controller.repeat();
    }
  }

  void _onTick() {
    final now = _controller.lastElapsedDuration ?? Duration.zero;
    final dt = (now - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = now;
    // Target speed: 0.012 per ~16ms frame = 0.75/sec
    setState(() {
      _time += dt * 0.75;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled && _controller.isAnimating) {
      _controller.stop();
    } else if (!disabled && !_controller.isAnimating && _shader != null) {
      _startIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_shader != null && !disableAnimations)
          RepaintBoundary(
            child: CustomPaint(
              painter: _VortexPainter(
                shader: _shader!,
                time: _time,
              ),
            ),
          )
        else
          const ColoredBox(color: Color(0xFF050510)),
        widget.child,
      ],
    );
  }
}

class _VortexPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;

  _VortexPainter({required this.shader, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // u_time (float at index 0)
    shader.setFloat(0, time);
    // u_resolution (vec2 at indices 1, 2)
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    // u_center (vec2 at indices 3, 4)
    shader.setFloat(3, size.width / 2);
    shader.setFloat(4, size.height / 2);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_VortexPainter oldDelegate) => oldDelegate.time != time;
}
