import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final double overlayOpacity;

  const AppBackground({
    super.key,
    this.overlayOpacity = 0.65,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/tsg_industrial_bg.png',
          fit: BoxFit.cover,
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
                Colors.black.withValues(alpha: 0.20),
                Colors.black.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.36),
              ],
            ),
          ),
        ),
      ],
    );
  }
}