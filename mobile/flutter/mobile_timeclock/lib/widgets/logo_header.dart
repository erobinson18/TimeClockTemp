import 'package:flutter/material.dart';

class LogoHeader extends StatelessWidget {
  /// Height as a fraction of screen height.
  /// Example: 0.20 = 20% of height.
  final double heightFactor;

  /// Optional padding around the logo.
  final EdgeInsets padding;

  /// Optional max height cap (helps on very large tablets).
  final double maxHeight;

  /// Optional min height cap (helps on smaller screens).
  final double minHeight;

  const LogoHeader({
    super.key,
    this.heightFactor = 0.20,
    this.padding = const EdgeInsets.only(top: 10, left: 12, right: 12),
    this.maxHeight = 240,
    this.minHeight = 80,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final desired = h * heightFactor;
    final logoHeight = desired.clamp(minHeight, maxHeight);

    return Padding(
      padding: padding,
      child: Center(
        child: Image.asset(
          'assets/images/the_systems_group_logo.png',
          height: logoHeight,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}