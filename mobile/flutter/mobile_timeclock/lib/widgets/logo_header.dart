import 'package:flutter/material.dart';

class LogoHeader extends StatelessWidget {
  final double heightFactor;
  final EdgeInsets padding;
  final double maxHeight;
  final double minHeight;
  final BoxFit fit;

  const LogoHeader({
    super.key,
    this.heightFactor = 0.24,
    this.padding = const EdgeInsets.only(top: 10, left: 12, right: 12),
    this.maxHeight = 290,
    this.minHeight = 96,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;

    final responsiveBoost = shortestSide < 600 ? 0.86 : 1.0;
    final desired = size.height * heightFactor * responsiveBoost;
    final logoHeight = desired.clamp(minHeight, maxHeight).toDouble();

    return Padding(
      padding: padding,
      child: Center(
        child: Image.asset(
          'assets/images/the_systems_group_logo.png',
          height: logoHeight,
          fit: fit,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}