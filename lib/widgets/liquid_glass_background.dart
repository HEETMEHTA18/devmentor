import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class LiquidGlassBackground extends StatelessWidget {
  final Widget child;

  const LiquidGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Light Theme Liquid Colors (Soft, vibrant pastels)
    final lightColors = [
      const Color(0xFFFFD1E1).withOpacity(0.45), // Soft Pink
      const Color(0xFFC7E9FF).withOpacity(0.55), // Soft Sky Blue
      const Color(0xFFE2D6FF).withOpacity(0.5),  // Soft Lavender
      const Color(0xFFD3F4EC).withOpacity(0.4),  // Soft Mint
    ];

    // Dark Theme Liquid Colors (Sleek, dark carbon & zinc hues)
    final darkColors = [
      const Color(0xFF27272A).withOpacity(0.25), // Slate Gray
      const Color(0xFF3F3F46).withOpacity(0.2),  // Medium Gray
      const Color(0xFF18181B).withOpacity(0.35), // Carbon
      const Color(0xFF52525B).withOpacity(0.15), // Silver Gray
    ];

    final colors = isDark ? darkColors : lightColors;
    final baseBg = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FC);

    return Scaffold(
      backgroundColor: baseBg,
      body: Stack(
        children: [
          // 1. Base Solid Color
          Positioned.fill(
            child: Container(color: baseBg),
          ),
          
          // 2. Liquid Orbs/Blobs
          // Orb 1 (Top Left)
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors[0],
                    colors[0].withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          
          // Orb 2 (Bottom Right)
          Positioned(
            bottom: -200,
            right: -100,
            child: Container(
              width: 550,
              height: 550,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors[1],
                    colors[1].withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          
          // Orb 3 (Center Right)
          Positioned(
            top: 250,
            right: -150,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors[2],
                    colors[2].withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Orb 4 (Bottom Left/Center)
          Positioned(
            bottom: 100,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors[3],
                    colors[3].withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // 3. Blur Filter to blend the orbs smoothly
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

          // 4. Content Screen
          Positioned.fill(
            child: child,
          ),
        ],
      ),
    );
  }
}
