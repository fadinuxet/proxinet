import 'package:flutter/material.dart';

class PutraceDesign {
  PutraceDesign._();

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;

  static const EdgeInsets paddingCard = EdgeInsets.all(16);
  static const EdgeInsets paddingChip =
      EdgeInsets.symmetric(horizontal: 14, vertical: 10);

  static List<BoxShadow> softElevation(Color base, {double opacity = 0.12}) => [
        BoxShadow(
          color: base.withValues(alpha: opacity),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static LinearGradient primaryGradient(ColorScheme scheme) => LinearGradient(
        colors: [scheme.primary, scheme.tertiary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient cardGradient(ColorScheme scheme) => LinearGradient(
        colors: [
          scheme.primaryContainer.withValues(alpha: 0.75),
          scheme.secondaryContainer.withValues(alpha: 0.55),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Motion tokens
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionMedium = Duration(milliseconds: 250);
  static const Curve motionCurve = Curves.easeOut;
}

class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadiusGeometry borderRadius;
  final List<Color>? colors;
  final EdgeInsetsGeometry padding;

  const GradientButton(
      {super.key,
      required this.child,
      required this.onPressed,
      this.borderRadius = const BorderRadius.all(Radius.circular(12)),
      this.colors,
      this.padding = const EdgeInsets.symmetric(vertical: 12)});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gradientColors = colors ?? [scheme.primary, scheme.tertiary];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: borderRadius,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: padding,
          shape: RoundedRectangleBorder(
              borderRadius: borderRadius as BorderRadius),
        ),
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
            child: child),
      ),
    );
  }
}

class AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadiusGeometry borderRadius;
  const AnimatedPressable(
      {super.key,
      required this.child,
      this.onTap,
      this.borderRadius = const BorderRadius.all(Radius.circular(12))});

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> {
  double _scale = 1.0;

  void _down(dynamic _) => setState(() => _scale = 0.98);
  void _up(dynamic _) => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _down : null,
      onTapUp: widget.onTap != null ? _up : null,
      onTapCancel: widget.onTap != null ? () => _up(null) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child:
            ClipRRect(borderRadius: widget.borderRadius, child: widget.child),
      ),
    );
  }
}
