import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import '../core/theme/app_theme.dart';

class LiquidGlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final double? width;
  final double? height;

  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.borderRadius = 32,
    this.color,
    this.width,
    this.height,
  });

  factory LiquidGlassButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    double borderRadius = 32,
    Color? color,
    double? width,
    double? height,
  }) {
    return LiquidGlassButton(
      key: key,
      onPressed: onPressed,
      padding: padding,
      borderRadius: borderRadius,
      color: color,
      width: width,
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          label,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (width != null || height != null) {
      content = SizedBox(
        width: width,
        height: height,
        child: Center(child: content),
      );
    }

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: MouseRegion(
        cursor: onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: onPressed == null ? 0.5 : 1.0,
            child: OCLiquidGlassGroup(
              settings: const OCLiquidGlassSettings(
                refractStrength: -0.05,
                blurRadiusPx: 2.0,
                specStrength: 25.0,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: OCLiquidGlass(
                      borderRadius: borderRadius,
                      color: color ?? AppTheme.accent.withOpacity(0.2),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
