import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final double overlayOpacity;
  final bool showVignette;

  const AppBackground({
    super.key,
    this.overlayOpacity = 0.65,
    this.showVignette = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/tsg_industrial_bg.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
        Container(
          color: Colors.black.withValues(alpha: overlayOpacity),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.24),
                Colors.black.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.40),
              ],
            ),
          ),
        ),
        if (showVignette)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.30),
                ],
              ),
            ),
          ),
      ],
    );
  }
}