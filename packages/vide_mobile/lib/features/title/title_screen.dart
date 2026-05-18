import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/effects/vortex_background.dart';
import '../../core/theme/tokens.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: VortexBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VIDE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: VideColors.textPrimary,
                  letterSpacing: 12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your AI-powered terminal IDE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: VideColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
