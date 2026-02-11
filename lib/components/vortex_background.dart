import 'dart:math';

import 'package:nocterm/nocterm.dart';

/// A subtle animated vortex background effect matching the landing page.
///
/// Renders a field of block characters (`░▒▓█▓▒░`) in a rotating spiral
/// pattern that radiates from the center of the terminal. The color palette
/// and algorithm are ported directly from the landing page WebGL shader.
///
/// The [child] widget is rendered on top of the vortex background using a
/// Stack layout.
///
/// Usage:
/// ```dart
/// VortexBackground(
///   child: Center(child: Text('Hello')),
/// )
/// ```
class VortexBackground extends StatefulComponent {
  final Component child;

  const VortexBackground({
    required this.child,
    super.key,
  });

  @override
  State<VortexBackground> createState() => _VortexBackgroundState();
}

class _VortexBackgroundState extends State<VortexBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 16000),
      vsync: this,
    );
    _controller.addListener(_onTick);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    setState(() {
      _time += 0.012; // Match landing page speed
    });
  }

  @override
  Component build(BuildContext context) {
    return Stack(
      children: [
        _VortexLayer(time: _time),
        component.child,
      ],
    );
  }
}

/// The actual vortex rendering layer — ported from landing page WebGL shader.
class _VortexLayer extends StatelessComponent {
  final double time;

  const _VortexLayer({required this.time});

  // Match landing page: ░▒▓█▓▒░
  static const _glyphs = ['░', '▒', '▓', '█', '▓', '▒', '░'];

  @override
  Component build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth.toInt();
        final rows = constraints.maxHeight.toInt();

        if (cols <= 0 || rows <= 0) return Text('');

        final centerX = cols / 2.0;
        final centerY = rows / 2.0;
        final maxDist =
            max(centerX, rows / 2.0) * 1.2; // Match shader: max(centerX, totalRows/2) * 1.2

        final lineComponents = <Component>[];

        for (int row = 0; row < rows; row++) {
          final buffer = StringBuffer();
          final colors = <_CharColor>[];

          for (int col = 0; col < cols; col++) {
            final dx = col - centerX;
            final dy = (row - centerY) * 1.8; // Match shader aspectRatio
            final dist = sqrt(dx * dx + dy * dy);
            final angle = atan2(dy, dx);

            // Spiral pattern — exact shader values
            const spiralTightness = 0.08;
            const rotationSpeed = 0.4;
            const waveFreq = 0.2;
            const radialWeight = 0.3;

            final spiralAngle =
                angle + dist * spiralTightness - time * rotationSpeed;
            final spiralValue = sin(spiralAngle * 2.0) * 0.5 + 0.5;
            final radialWave =
                sin(dist * waveFreq - time * 0.6) * 0.5 + 0.5;
            final intensity = spiralValue * (1.0 - radialWeight) +
                radialWave * radialWeight;

            // Distance fade — match shader
            final normalizedDist = (dist / maxDist).clamp(0.0, 1.0);
            final distFade = 1.0 - normalizedDist;
            final finalIntensity = intensity * (0.15 + distFade * 0.6);

            // Pick glyph
            final glyphIndex = (finalIntensity * (_glyphs.length - 1))
                .floor()
                .clamp(0, _glyphs.length - 1);

            // Dark blue background matching landing page: vec3(0.02, 0.02, 0.04)
            const bgR = 5;
            const bgG = 5;
            const bgB = 10;

            // Skip rendering for very low intensity
            if (finalIntensity < 0.05) {
              buffer.write(' ');
              colors.add(const _CharColor(0, 0, 0, bgR, bgG, bgB));
              continue;
            }

            final char = _glyphs[glyphIndex];

            // Color: teal/cyan palette matching the landing page.
            // Use finalIntensity to drive brightness directly (like bento
            // plasma example) — no alpha compositing simulation needed.
            final fade = finalIntensity * (1.0 - normalizedDist * 0.4);
            final colorShift = sin(time * 0.5 + dist * 0.05) * 10.0;

            final cr = (fade * 30 + (normalizedDist < 0.25
                    ? (0.25 - normalizedDist) / 0.25 * 50
                    : 0))
                .toInt()
                .clamp(0, 255);
            final cg = (fade * 120 + 15 + colorShift)
                .toInt()
                .clamp(8, 160);
            final cb = (fade * 160 + 25 + colorShift * 0.5)
                .toInt()
                .clamp(12, 220);

            buffer.write(char);
            colors.add(_CharColor(cr, cg, cb, bgR, bgG, bgB));
          }

          // Group consecutive chars with the same color into spans
          final lineChars = buffer.toString();
          final spans = <Component>[];
          var spanStart = 0;

          for (int i = 1; i <= lineChars.length; i++) {
            if (i == lineChars.length ||
                colors[i].r != colors[spanStart].r ||
                colors[i].g != colors[spanStart].g ||
                colors[i].b != colors[spanStart].b ||
                colors[i].bgR != colors[spanStart].bgR ||
                colors[i].bgG != colors[spanStart].bgG ||
                colors[i].bgB != colors[spanStart].bgB) {
              final c = colors[spanStart];
              final spanText = lineChars.substring(spanStart, i);
              final bgColor = Color.fromRGB(c.bgR, c.bgG, c.bgB);
              if (c.r > 0 || c.g > 0 || c.b > 0) {
                spans.add(
                  Text(
                    spanText,
                    style: TextStyle(
                      color: Color.fromRGB(c.r, c.g, c.b),
                      backgroundColor: bgColor,
                    ),
                  ),
                );
              } else {
                spans.add(Text(
                  spanText,
                  style: TextStyle(backgroundColor: bgColor),
                ));
              }
              spanStart = i;
            }
          }

          lineComponents
              .add(Row(mainAxisSize: MainAxisSize.min, children: spans));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lineComponents,
        );
      },
    );
  }
}

class _CharColor {
  final int r, g, b;
  final int bgR, bgG, bgB;
  const _CharColor(this.r, this.g, this.b, this.bgR, this.bgG, this.bgB);
}
